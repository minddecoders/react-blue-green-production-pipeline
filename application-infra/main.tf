
# ============================================================================
# PHASE 1: TARGET CLOUD PROVIDER PLUGINS & REMOTING BACKEND
# ============================================================================
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket       = "sidra-prod-state-vault-2026"
    key          = "react-blue-green-pipeline/terraform.tfstate"
    region       = "eu-west-1"
    use_lockfile = true
  }
}

provider "aws" {
  region = var.aws_region
}
# ============================================================================
# 🛰️ SSM: Retrieve the currently approved Blue Docker image
# ============================================================================
data "aws_ssm_parameter" "current_approved_image" {
  name = "/current/react-recipeapp-blue-green-image"
}

locals {
  approved_blue_image = var.container_image != null ? var.container_image : data.aws_ssm_parameter.current_approved_image.value
}

# ============================================================================
# PHASE 1.1: WORKSPACE-SPECIFIC ENVIRONMENT CONFIGURATION (LOCALS)
# ============================================================================
locals {
  instance_sizes = {
    default = "t3.micro"
    dev     = "t3.micro"
    staging = "t3.small"
    prod    = "t3.medium"
  }

  # 🔵 Stable Blue Scale Map
  blue_ecs_task_counts = {
    default = 0
    dev     = 1
    staging = 1
    prod    = 2
  }

  current_instance_type = lookup(local.instance_sizes, terraform.workspace, "t3.micro")
  current_blue_scale    = lookup(local.blue_ecs_task_counts, terraform.workspace, 0)

  # 🟢 Dynamic Green Scale Map: If the workflow passes var.green_ecs_scale, use it! 
  # Otherwise, fallback to matching the blue baseline scale.
  current_green_scale = var.green_ecs_scale != null ? var.green_ecs_scale : local.current_blue_scale
}


# ============================================================================
# PHASE 2: STRUCTURAL NETWORK ARCHITECTURE
# ============================================================================
resource "aws_vpc" "react_clouddeploye_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "react-clouddeploye-${terraform.workspace}-vpc"
  }
}

resource "aws_internet_gateway" "react_clouddeploye_igw" {
  vpc_id = aws_vpc.react_clouddeploye_vpc.id
}

resource "aws_route_table" "react_clouddeploye_public_rt" {
  vpc_id = aws_vpc.react_clouddeploye_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.react_clouddeploye_igw.id
  }
}

resource "aws_subnet" "react_clouddeploye_public_subnet" {
  vpc_id            = aws_vpc.react_clouddeploye_vpc.id
  cidr_block        = var.public_subnet_cidr
  availability_zone = "${var.aws_region}a"

  tags = {
    Name = "react-clouddeploye-${terraform.workspace}-public-subnet-1a"
  }
}

resource "aws_route_table_association" "react_clouddeploye_public_assoc" {
  subnet_id      = aws_subnet.react_clouddeploye_public_subnet.id
  route_table_id = aws_route_table.react_clouddeploye_public_rt.id
}

resource "aws_subnet" "react_clouddeploye_public_subnet_b" {
  vpc_id            = aws_vpc.react_clouddeploye_vpc.id
  cidr_block        = var.public_subnet_b_cidr
  availability_zone = "${var.aws_region}b"

  tags = {
    Name = "react-clouddeploye-${terraform.workspace}-public-subnet-1b"
  }
}

resource "aws_route_table_association" "react_clouddeploye_public_b_assoc" {
  subnet_id      = aws_subnet.react_clouddeploye_public_subnet_b.id
  route_table_id = aws_route_table.react_clouddeploye_public_rt.id
}

resource "aws_security_group" "react_clouddeploye_web_sg" {
  name        = "react-clouddeploye-${terraform.workspace}-web-sg"
  vpc_id      = aws_vpc.react_clouddeploye_vpc.id
  description = "Isolate instances and manage load balancer web ingress rules"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ============================================================================
# PHASE 3: SECURE IAM IDENTITY MANAGEMENT (WORKSPACE ISOLATED NAMES)
# ============================================================================
resource "aws_iam_role" "react_clouddeploye_ssm_role" {
  name = "EC2-SSM-Core-Role-react-${terraform.workspace}-cicd-2026"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "react_clouddeploye_ssm_attach" {
  role       = aws_iam_role.react_clouddeploye_ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "react_clouddeploye_ssm_profile" {
  name = "EC2-SSM-Instance-Profile-react-${terraform.workspace}-cicd-2026"
  role = aws_iam_role.react_clouddeploye_ssm_role.name
}

# ============================================================================
# PHASE 4: COMPLIANT KEYLESS COMPUTE ENGINE
# ============================================================================
resource "aws_instance" "react_clouddeploye_ssm_vm" {
  ami                         = var.public_instance_ami
  instance_type               = local.current_instance_type
  subnet_id                   = aws_subnet.react_clouddeploye_public_subnet.id
  vpc_security_group_ids      = [aws_security_group.react_clouddeploye_web_sg.id]
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.react_clouddeploye_ssm_profile.name

  user_data = <<-EOF
              #!/bin/bash
              sudo apt-get update -y
              sudo apt-get install nginx -y
              sudo systemctl start nginx
              sudo systemctl enable nginx
              EOF

  tags = {
    Name      = "react-clouddeploye-${terraform.workspace}-ssm-terraform-demo"
    ManagedBy = "Terraform-IaC"
  }
}

# ============================================================================
# PHASE 5: ISOLATED PRIVATE NETWORK & SECURITY ISOLATION TIER
# ============================================================================
resource "aws_subnet" "react_clouddeploye_private_subnet" {
  vpc_id            = aws_vpc.react_clouddeploye_vpc.id
  cidr_block        = var.private_subnet_cidr
  availability_zone = "${var.aws_region}b"

  tags = {
    Name = "react-clouddeploye-${terraform.workspace}-private-1b"
  }
}

resource "aws_route_table" "react_clouddeploye_private_rt" {
  vpc_id = aws_vpc.react_clouddeploye_vpc.id

  tags = {
    Name        = "react-clouddeploye-${terraform.workspace}-private-rt"
    Environment = terraform.workspace
  }
}

resource "aws_route_table_association" "react_clouddeploye_private_assoc" {
  subnet_id      = aws_subnet.react_clouddeploye_private_subnet.id
  route_table_id = aws_route_table.react_clouddeploye_private_rt.id
}

resource "aws_security_group" "react_clouddeploye_private_db_sg" {
  name        = "react-clouddeploye-${terraform.workspace}-private-db-sg"
  description = "Block all public access and whitelist internal database traffic queries only"
  vpc_id      = aws_vpc.react_clouddeploye_vpc.id

  ingress {
    description     = "Allow internal database queries exclusively from the front-end web tier"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.react_clouddeploye_web_sg.id]
  }

  ingress {
    description     = "Allow internal management traffic from the public web host"
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [aws_security_group.react_clouddeploye_web_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "react-clouddeploye-${terraform.workspace}-private-db-sg"
    Environment = terraform.workspace
  }
}

resource "aws_instance" "react_clouddeploye_private_vm" {
  ami                    = var.private_instance_ami
  instance_type          = local.current_instance_type
  subnet_id              = aws_subnet.react_clouddeploye_private_subnet.id
  vpc_security_group_ids = [aws_security_group.react_clouddeploye_private_db_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.react_clouddeploye_ssm_profile.name

  tags = {
    Name      = "react-clouddeploye-${terraform.workspace}-ssm-private-backend"
    ManagedBy = "Terraform-IaC"
  }
}

# ============================================================================
# PHASE 6: SERVERLESS CONTAINER ORCHESTRATION (ECS & FARGATE)
# ============================================================================
resource "aws_cloudwatch_log_group" "react_clouddeploye_ecs_log_group" {
  name              = "/ecs/react-social-link-app-${terraform.workspace}-logs"
  retention_in_days = 7

  tags = {
    Environment = terraform.workspace
    ManagedBy   = "Terraform-IaC"
  }
}

resource "aws_ecs_cluster" "react_social_link_cluster" {
  name = "react-social-link-app-${terraform.workspace}-cluster"

  tags = {
    Environment = terraform.workspace
    ManagedBy   = "Terraform-IaC"
  }
}

resource "aws_iam_role" "react_social_link_ecs_task_execution_role" {
  name = "react-social-link-app-ecs-execution-${terraform.workspace}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Environment = terraform.workspace
    ManagedBy   = "Terraform-IaC"
  }
}

resource "aws_iam_role_policy_attachment" "react_social_link_ecs_task_execution" {
  role       = aws_iam_role.react_social_link_ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# 🔵 BLUE ECS TASK DEFINITION
resource "aws_ecs_task_definition" "react_social_link_task" {
  family                   = "react-social-link-app-blue-${terraform.workspace}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.react_social_link_ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "react-social-link-app"
      image     = local.approved_blue_image
      essential = true

      portMappings = [{
        containerPort = var.container_port
        hostPort      = var.container_port
        protocol      = "tcp"
      }]

      logConfiguration = {
        logDriver = "awslogs"

        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.react_clouddeploye_ecs_log_group.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])

  tags = {
    Environment = terraform.workspace
    ManagedBy   = "Terraform-IaC"
  }
}

# 🔵 BLUE ECS SERVICE
resource "aws_ecs_service" "react_social_link_service" {
  name            = "react-social-link-app-blue-service"
  cluster         = aws_ecs_cluster.react_social_link_cluster.id
  task_definition = aws_ecs_task_definition.react_social_link_task.arn
  desired_count   = local.current_blue_scale
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [aws_subnet.react_clouddeploye_public_subnet.id, aws_subnet.react_clouddeploye_public_subnet_b.id]
    security_groups  = [aws_security_group.react_clouddeploye_web_sg.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.react_social_link_ecs_tg.arn
    container_name   = "react-social-link-app"
    container_port   = var.container_port
  }

  depends_on = [
    aws_iam_role_policy_attachment.react_social_link_ecs_task_execution,
    aws_lb_listener.react_social_link_http_listener
  ]
}

# ============================================================================
# PHASE 7: ENTERPRISE HIGH-AVAILABILITY APPLICATION LOAD BALANCER
# ============================================================================

resource "aws_lb" "react_social_link_alb" {
  name               = "react-social-${terraform.workspace}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.react_clouddeploye_web_sg.id]
  subnets            = [aws_subnet.react_clouddeploye_public_subnet.id, aws_subnet.react_clouddeploye_public_subnet_b.id]

  tags = {
    Environment = terraform.workspace
    ManagedBy   = "Terraform-IaC"
  }
}

# 🔵 BLUE TARGET GROUP
resource "aws_lb_target_group" "react_social_link_ecs_tg" {
  name        = "react-${terraform.workspace}-ecs-tg-blue"
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = aws_vpc.react_clouddeploye_vpc.id
  target_type = "ip"

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }

  tags = {
    Environment = terraform.workspace
    ManagedBy   = "Terraform-IaC"
  }
}

resource "aws_lb_listener" "react_social_link_http_listener" {
  load_balancer_arn = aws_lb.react_social_link_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.react_social_link_ecs_tg.arn
  }
}

# ============================================================================
# 🍏 PHASE 7.2: ENTERPRISE REDUNDANCY • BLUE-GREEN IMMUTABLE ROUTING SWITCHES
# ============================================================================

# 🟢 GREEN TARGET GROUP
resource "aws_lb_target_group" "react_social_link_ecs_tg_green" {
  name        = "react-${terraform.workspace}-ecs-tg-green"
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = aws_vpc.react_clouddeploye_vpc.id
  target_type = "ip"

  health_check {
    path     = "/"
    protocol = "HTTP"
    matcher  = "200"
  }

  tags = {
    Environment = terraform.workspace
    Deployment  = "Immutable-Green-Tier"
  }
}

# 🟢 GREEN ECS TASK DEFINITION
resource "aws_ecs_task_definition" "react_social_link_green_task" {
  family                   = "react-social-link-app-green-${terraform.workspace}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.react_social_link_ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "react-social-link-app-green"
      image     = var.green_container_image
      essential = true

      portMappings = [{
        containerPort = var.container_port
        hostPort      = var.container_port
        protocol      = "tcp"
      }]

      logConfiguration = {
        logDriver = "awslogs"

        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.react_clouddeploye_ecs_log_group.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "green"
        }
      }
    }
  ])

  tags = {
    Environment = terraform.workspace
    Deployment  = "Green"
    ManagedBy   = "Terraform-IaC"
  }
}

# 🟢 GREEN ECS SERVICE
resource "aws_ecs_service" "react_social_link_green_service" {
  name            = "react-social-link-app-green-service"
  cluster         = aws_ecs_cluster.react_social_link_cluster.id
  task_definition = aws_ecs_task_definition.react_social_link_green_task.arn
  desired_count   = local.current_green_scale
  launch_type     = "FARGATE"
  wait_for_steady_state = true

  network_configuration {
    subnets          = [aws_subnet.react_clouddeploye_public_subnet.id, aws_subnet.react_clouddeploye_public_subnet_b.id]
    security_groups  = [aws_security_group.react_clouddeploye_web_sg.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.react_social_link_ecs_tg_green.arn
    container_name   = "react-social-link-app-green"
    container_port   = var.container_port
  }

  depends_on = [
    aws_iam_role_policy_attachment.react_social_link_ecs_task_execution,
    aws_lb_listener.react_social_link_http_listener
  ]

  tags = {
    Environment = terraform.workspace
    Deployment  = "Green"
    ManagedBy   = "Terraform-IaC"
  }
}


# ============================================================================
# 🎛️ 1. THE DEFAULT WEIGHTED TRAFFIC SWAP CONTROLLER (Priority 100)
# ============================================================================
resource "aws_lb_listener_rule" "blue_green_router" {
  listener_arn = aws_lb_listener.react_social_link_http_listener.arn
  priority     = 100

  action {
    type = "forward"

    forward {
      # 🔵 Blue Target Group (Active Production)
      target_group {
        arn    = aws_lb_target_group.react_social_link_ecs_tg.arn
        weight = var.blue_traffic_weight
      }

      # 🟢 Green Target Group (Staging Canary)
      target_group {
        arn    = aws_lb_target_group.react_social_link_ecs_tg_green.arn
        weight = var.green_traffic_weight
      }
    }
  }

  condition {
    path_pattern {
      values = ["/*"]
    }
  }
}

# ============================================================================
# 🧪 2. THE CANARY SMOKE-TEST GATEWAY INTERCEPTOR (Priority 90)
# ============================================================================
resource "aws_lb_listener_rule" "green_smoke_test" {
  listener_arn = aws_lb_listener.react_social_link_http_listener.arn
  priority     = 90 # ⚡ Evaluated BEFORE the default rule to catch test headers!

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.react_social_link_ecs_tg_green.arn
  }

  # Whitelists background connections matching your specific test token keys
  condition {
    http_header {
      http_header_name = "X-Blue-Green-Test"
      values           = ["true"]
    }
  }

  condition {
    path_pattern {
      values = ["/*"]
    }
  }
}

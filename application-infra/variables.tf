# ============================================================================
# 🍏 VARIABLES.TF: ENTERPRISE BLUE-GREEN DEPLOYMENT CONFIGURATIONS
# ============================================================================

variable "aws_region" {
  type        = string
  description = "The AWS Target Deployment Region"
  default     = "eu-west-1"
}

variable "vpc_cidr" {
  type        = string
  description = "Base CIDR range for the automated VPC"
  default     = "10.20.0.0/16"
}

variable "public_subnet_cidr" {
  type        = string
  description = "CIDR range for the front-facing public web tier"
  default     = "10.20.1.0/24"
}

# 🛡️ ALB must have at least two public subnets in different AZs
variable "public_subnet_b_cidr" {
  type        = string
  description = "CIDR block for the second redundant public subnet tier"
  default     = "10.20.3.0/24"
}

variable "private_subnet_cidr" {
  type        = string
  description = "CIDR range for the isolated backend database tier"
  default     = "10.20.2.0/24"
}

variable "public_instance_ami" {
  type        = string
  description = "AMI ID for the public Nginx web server"
  default     = "ami-04df7d76c1b804451" # Ubuntu 22.04 LTS
}

variable "private_instance_ami" {
  type        = string
  description = "AMI ID for the isolated backend server"
  default     = "ami-04df7d76c1b804451" # Ubuntu 22.04 LTS
}

variable "instance_type" {
  type        = string
  description = "EC2 computing tier footprint size"
  default     = "t3.micro"
}

# 🐳 Docker Configuration
variable "container_port" {
  type        = number
  description = "Port exposed by the container"
  default     = 80
}
# 🍏 Green Blue
variable "container_image" {
  type        = string
  description = "Docker Hub image used by the standard Blue ECS Fargate task"
  default     = "minddecoders/react-recipeapp-blue-green-production:v1.0"
}

variable "green_container_image" {
  type        = string
  description = "Docker Hub image version passed dynamically from GitHub Actions"
  default     = "minddecoders/react-recipeapp-blue-green-production:v1.0" # Changed default away from :latest to track drift clearly
}

# 🎛️ Blue-Green Routing Controllers
# These connect directly to the aws_lb_listener_rule in your main.tf file!
variable "blue_traffic_weight" {
  type        = number
  description = "Percentage of active production traffic routed to the stable Blue service"
  default     = 100
}

variable "green_traffic_weight" {
  type        = number
  description = "Percentage of active production traffic routed to the staging Green service"
  default     = 0
}

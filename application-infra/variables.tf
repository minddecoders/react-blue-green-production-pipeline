# ============================================================================
# 🇮🇪 REGION 1: PRIMARY ENVIRONMENT CONFIGURATION METRICS (IRELAND)
# ============================================================================

variable "aws_region" {
  type        = string
  description = "The primary active geographical deployment zone"
  default     = "eu-west-1"
}

variable "vpc_cidr" {
  type        = string
  description = "Base network address block for the primary Ireland VPC"
  default     = "10.20.0.0/16"
}

variable "public_subnet_cidr" {
  type        = string
  description = "Network address slice for public subnet A in Ireland"
  default     = "10.20.1.0/24"
}

variable "public_subnet_b_cidr" {
  type        = string
  description = "Network address slice for public subnet B in Ireland"
  default     = "10.20.3.0/24"
}

variable "private_subnet_cidr" {
  type        = string
  description = "Isolated network address space for internal databases"
  default     = "10.20.2.0/24"
}

variable "public_instance_ami" {
  type        = string
  description = "AMI ID for the public Nginx web server"
  default     = "ami-04df7d76c1b804451" # Canonical Ubuntu Server 22.04 LTS
}

variable "private_instance_ami" {
  type        = string
  description = "AMI ID for the isolated backend server"
  default     = "ami-04df7d76c1b804451"
}

variable "instance_type" {
  type        = string
  description = "EC2 computing tier footprint size"
  default     = "t3.micro"
}

# ============================================================================
# 🇺🇸 REGION 2: DISASTER RECOVERY ENVIRONMENT METRICS (N. VIRGINIA)
# ============================================================================

variable "aws_backup_region" {
  type        = string
  description = "The secondary emergency backup geographical deployment zone"
  default     = "us-east-1"
}

variable "dr_vpc_cidr" {
  type        = string
  description = "Isolated network address block for the secondary US VPC"
  default     = "10.40.0.0/16" # 🛡️ Safely isolated from Ireland's 10.20.x.x!
}

variable "dr_public_subnet_a_cidr" {
  type        = string
  description = "Network address slice for public subnet A in North Virginia"
  default     = "10.40.1.0/24"
}

variable "dr_public_subnet_b_cidr" {
  type        = string
  description = "Network address slice for public subnet B in North Virginia"
  default     = "10.40.3.0/24"
}

# ============================================================================
# 🐳 CORE DOCKER APPLICATIVE CONTAINER IMAGES AND POINTERS
# ============================================================================

variable "container_image" {
  type        = string
  description = "Docker Hub image path used by the stable Blue compute tasks"
  default     = null # 🔑 Decoupled from hardcoded string variables
}

variable "green_container_image" {
  type        = string
  description = "Docker Hub image tag updated dynamically via automation pipelines"
  default     = "minddecoders/react-social-link-app:latest"
}

variable "container_port" {
  type        = number
  description = "The internal listening port exposed by the application process"
  default     = 80
}

variable "green_ecs_scale" {
  type        = number
  description = "Dynamic task counts pass-through variable flag for smoke testing"
  default     = null
}

# ============================================================================
# 🎛️ TRAFFIC BALANCING CONTROL WEIGHT METRICS
# ============================================================================

variable "blue_traffic_weight" {
  type        = number
  description = "Percentage split routed to the active Blue service tier"
  default     = 100
}

variable "green_traffic_weight" {
  type        = number
  description = "Percentage split routed to the staging Green service tier"
  default     = 0
}

variable "domain_name" {
  type        = string
  description = "The authoritative production web domain for public routing maps"
  default     = "sidrashoppe.com"
}

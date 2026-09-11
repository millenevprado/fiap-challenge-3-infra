variable "aws_region" {
  description = "AWS region where everything will be provisioned."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Prefix used in resource names."
  type        = string
  default     = "togglemaster"
}

variable "vpc_cidr" {
  description = "IP range of the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "azs" {
  description = "Availability Zones used to distribute the subnets."
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "public_subnet_cidrs" {
  description = "CIDRs of the public subnets, one per AZ."
  type        = list(string)
  default     = ["10.0.1.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDRs of the private subnets, one per AZ."
  type        = list(string)
  default     = ["10.0.2.0/24", "10.0.3.0/24"]
}

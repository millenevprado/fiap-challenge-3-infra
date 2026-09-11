variable "project_name" {
  description = "Prefix used in resource names."
  type        = string
}

variable "vpc_cidr" {
  description = "IP range of the VPC."
  type        = string
}

variable "azs" {
  description = "Availability Zones used to distribute the subnets."
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "CIDRs of the public subnets, one per AZ."
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "CIDRs of the private subnets, one per AZ."
  type        = list(string)
}

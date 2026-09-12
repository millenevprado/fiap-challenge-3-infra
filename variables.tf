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

variable "eks_cluster_version" {
  description = "Kubernetes version of the EKS cluster."
  type        = string
  default     = "1.36"
}

variable "node_instance_types" {
  description = "EC2 instance types used by the Node Group."
  type        = list(string)
  default     = ["t3.small"]
}

variable "node_desired_size" {
  description = "Desired number of nodes in the Node Group."
  type        = number
  default     = 2
}

variable "node_min_size" {
  description = "Minimum number of nodes in the Node Group."
  type        = number
  default     = 1
}

variable "node_max_size" {
  description = "Maximum number of nodes in the Node Group."
  type        = number
  default     = 3
}

variable "rds_engine_version" {
  description = "PostgreSQL engine version."
  type        = string
  default     = "16.4"
}

variable "rds_instance_class" {
  description = "RDS instance class."
  type        = string
  default     = "db.t3.micro"
}

variable "rds_allocated_storage" {
  description = "Allocated storage in GB for each RDS instance."
  type        = number
  default     = 20
}

variable "redis_node_type" {
  description = "ElastiCache node instance type."
  type        = string
  default     = "cache.t3.micro"
}

variable "db_user" {
  description = "Master username for the RDS instances."
  type        = string
}

variable "db_pass" {
  description = "Master password for the RDS instances. Provide via TF_VAR_db_pass, never commit it."
  type        = string
  sensitive   = true

  validation {
    condition     = length(trimspace(var.db_pass)) >= 12
    error_message = "db_pass must be at least 12 characters long and provided via TF_VAR_db_pass."
  }
}

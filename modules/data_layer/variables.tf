variable "project_name" {
  description = "Prefix used in resource names."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the security group is created."
  type        = string
}

variable "eks_cluster_security_group_id" {
  description = "Security group ID of the EKS cluster, allowed to reach the databases."
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs used by the DB subnet group."
  type        = list(string)
}

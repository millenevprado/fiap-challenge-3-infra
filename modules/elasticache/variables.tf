variable "cluster_id" {
  description = "Unique identifier of the ElastiCache cluster."
  type        = string
}

variable "node_type" {
  description = "ElastiCache node instance type."
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs used by the cache subnet group (private subnets)."
  type        = list(string)
}

variable "vpc_security_group_ids" {
  description = "Security group IDs attached to the cluster."
  type        = list(string)
}

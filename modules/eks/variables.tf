variable "project_name" {
  description = "Prefix used in resource names."
  type        = string
}

variable "cluster_name" {
  description = "Name of the EKS cluster."
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version of the EKS cluster."
  type        = string
}

variable "cluster_subnet_ids" {
  description = "Subnet IDs used by the EKS control plane (public + private)."
  type        = list(string)
}

variable "node_subnet_ids" {
  description = "Subnet IDs used by the Node Group (private subnets)."
  type        = list(string)
}

variable "node_instance_types" {
  description = "EC2 instance types used by the Node Group."
  type        = list(string)
}

variable "node_desired_size" {
  description = "Desired number of nodes in the Node Group."
  type        = number
}

variable "node_min_size" {
  description = "Minimum number of nodes in the Node Group."
  type        = number
}

variable "node_max_size" {
  description = "Maximum number of nodes in the Node Group."
  type        = number
}

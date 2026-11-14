variable "project_name" {
  description = "Prefix used in resource names."
  type        = string
}

variable "aws_region" {
  description = "AWS region where the secrets being synced live."
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace where External Secrets Operator will be installed."
  type        = string
  default     = "external-secrets"
}

variable "chart_version" {
  description = "Version of the external-secrets Helm chart (external-secrets/external-secrets repo)."
  type        = string
  default     = "0.10.7"
}

variable "cluster_name" {
  description = "Name of the EKS cluster, used for the Pod Identity association."
  type        = string
}

variable "secret_arns" {
  description = "ARNs of the Secrets Manager secrets External Secrets Operator is allowed to read."
  type        = list(string)
}

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

variable "oidc_provider_arn" {
  description = "ARN of the EKS cluster's IAM OIDC provider, used to build the IRSA trust policy."
  type        = string
}

variable "oidc_provider_url" {
  description = "OIDC issuer URL (without the https:// scheme), used in the IRSA trust policy condition keys."
  type        = string
}

variable "secret_arns" {
  description = "ARNs of the Secrets Manager secrets External Secrets Operator is allowed to read."
  type        = list(string)
}

variable "role_name" {
  description = "Name of the IAM role assumed by the pod's service account."
  type        = string
}

variable "oidc_provider_arn" {
  description = "ARN of the EKS cluster's IAM OIDC provider."
  type        = string
}

variable "oidc_provider_url" {
  description = "OIDC issuer URL (without the https:// scheme), used in the IRSA trust policy condition keys."
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace of the service account this role is bound to."
  type        = string
}

variable "service_account_name" {
  description = "Name of the Kubernetes service account this role is bound to."
  type        = string
}

variable "policy_json" {
  description = "IAM policy document (JSON) granting the permissions this workload needs."
  type        = string
}

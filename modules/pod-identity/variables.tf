variable "role_name" {
  description = "Name of the IAM role assumed by the pod's service account."
  type        = string
}

variable "cluster_name" {
  description = "Name of the EKS cluster where the Pod Identity association is created."
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

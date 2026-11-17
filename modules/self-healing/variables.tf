variable "project_name" {
  description = "Prefix used in resource names."
  type        = string
}

variable "cluster_name" {
  description = "Name of the EKS cluster the runbook acts on."
  type        = string
}

variable "cluster_endpoint" {
  description = "HTTPS endpoint of the EKS API server."
  type        = string
}

variable "cluster_ca_data" {
  description = "Base64 CA certificate of the EKS cluster."
  type        = string
}

variable "secret_arn" {
  description = "ARN of the Secrets Manager secret holding selfheal_token and slack_webhook_url."
  type        = string
}

variable "namespace" {
  description = "Only namespace the runbook may act on."
  type        = string
  default     = "togglemaster"
}

variable "allowed_deployments" {
  description = "Deployments the runbook is allowed to restart."
  type        = list(string)
}

variable "cooldown_seconds" {
  description = "Minimum interval between two automatic restarts of the same deployment."
  type        = number
  default     = 300
}

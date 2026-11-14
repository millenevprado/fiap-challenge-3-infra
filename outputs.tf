output "evaluation_service_role_arn" {
  description = "IAM role of the evaluation-service ServiceAccount (EKS Pod Identity association)."
  value       = module.pod_identity_evaluation_service.role_arn
}

output "analytics_service_role_arn" {
  description = "IAM role of the analytics-service ServiceAccount (EKS Pod Identity association)."
  value       = module.pod_identity_analytics_service.role_arn
}

output "service_api_key_hash" {
  description = "SHA-256 hash to insert into auth-service's api_keys table (the plaintext key itself only lives in Secrets Manager)."
  value       = local.service_api_key_hash
}

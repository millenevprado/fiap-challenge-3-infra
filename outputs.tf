output "evaluation_service_irsa_role_arn" {
  description = "IAM role ARN to annotate the evaluation-service ServiceAccount with, in the gitops repo."
  value       = module.irsa_evaluation_service.role_arn
}

output "analytics_service_irsa_role_arn" {
  description = "IAM role ARN to annotate the analytics-service ServiceAccount with, in the gitops repo."
  value       = module.irsa_analytics_service.role_arn
}

output "service_api_key_hash" {
  description = "SHA-256 hash to insert into auth-service's api_keys table (the plaintext key itself only lives in Secrets Manager)."
  value       = local.service_api_key_hash
}

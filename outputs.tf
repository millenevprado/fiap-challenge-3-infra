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

output "self_healing_function_name" {
  description = "Self-healing Lambda (logs: CloudWatch /aws/lambda/<name>)."
  value       = module.self_healing.function_name
}

output "observability_secret_name" {
  description = "Secrets Manager secret with the observability credentials (incl. Grafana admin password)."
  value       = aws_secretsmanager_secret.observability.name
}

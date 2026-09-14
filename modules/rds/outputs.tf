output "endpoint" {
  value = aws_db_instance.postgres.endpoint
}

output "db_name" {
  value = aws_db_instance.postgres.db_name
}

output "secret_arn" {
  description = "ARN of the Secrets Manager secret holding this instance's credentials."
  value       = aws_secretsmanager_secret.credentials.arn
}

output "secret_name" {
  description = "Name of the Secrets Manager secret, used as the remoteRef.key in the gitops repo's ExternalSecret manifests."
  value       = aws_secretsmanager_secret.credentials.name
}

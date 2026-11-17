output "function_url" {
  description = "HTTPS URL Grafana's webhook contact point calls."
  value       = aws_lambda_function_url.this.function_url
}

output "function_name" {
  description = "Lambda function name (CloudWatch log group /aws/lambda/<name>)."
  value       = aws_lambda_function.this.function_name
}

output "role_arn" {
  description = "IAM role of the Lambda (EKS access entry principal)."
  value       = aws_iam_role.this.arn
}

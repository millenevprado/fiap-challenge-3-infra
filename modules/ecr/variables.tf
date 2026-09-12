variable "repository_names" {
  description = "Names of the ECR repositories to create, one per microservice."
  type        = list(string)
}

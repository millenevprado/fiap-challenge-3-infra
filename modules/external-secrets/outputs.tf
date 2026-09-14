output "namespace" {
  value = var.namespace
}

output "cluster_secret_store_name" {
  description = "Name of the ClusterSecretStore, used as secretStoreRef.name in the gitops repo's ExternalSecret manifests."
  value       = "aws-secretsmanager"
}

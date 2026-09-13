output "namespace" {
  value = kubernetes_namespace.argocd.metadata[0].name
}

output "server_service_name" {
  description = "Name of the argocd-server Service, used for kubectl port-forward."
  value       = "argocd-server"
}

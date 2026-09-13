variable "namespace" {
  description = "Kubernetes namespace where ArgoCD will be installed."
  type        = string
  default     = "argocd"
}

variable "chart_version" {
  description = "Version of the argo-cd Helm chart (argoproj/argo-helm repo)."
  type        = string
  default     = "10.9.0"
}

variable "server_service_type" {
  description = "Service type for argocd-server (ClusterIP, NodePort or LoadBalancer). ClusterIP + port-forward avoids LoadBalancer cost."
  type        = string
  default     = "ClusterIP"
}

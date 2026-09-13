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

variable "gitops_repo_url" {
  description = "URL of the GitOps Git repository containing the microservice manifests."
  type        = string
}

variable "gitops_target_revision" {
  description = "Branch/tag/commit of the GitOps repository to sync."
  type        = string
  default     = "master"
}

variable "app_namespace" {
  description = "Cluster namespace where the microservices are deployed (Applications' destination)."
  type        = string
  default     = "togglemaster"
}

variable "microservices" {
  description = "Microservices in the GitOps repository; each one becomes an ArgoCD Application pointing at the matching subdirectory."
  type        = list(string)
  default     = []
}

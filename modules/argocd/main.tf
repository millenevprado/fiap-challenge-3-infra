terraform {
  required_providers {
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.14"
    }
  }
}

resource "kubernetes_namespace" "argocd" {
  metadata {
    name = var.namespace
  }
}

resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.chart_version
  namespace  = kubernetes_namespace.argocd.metadata[0].name

  values = [
    yamlencode({
      server = {
        service = {
          type = var.server_service_type
        }
      }
    })
  ]
}

# One Application per microservice, pointing at the matching subdirectory in
# the GitOps repository. Automated sync (prune + selfHeal): any change in the
# repository is applied to the cluster with no manual intervention, and the
# cluster is reverted if someone edits resources outside of Git.
resource "kubectl_manifest" "app" {
  for_each = toset(var.microservices)

  yaml_body = yamlencode({
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = each.value
      namespace = kubernetes_namespace.argocd.metadata[0].name
    }
    spec = {
      project = "default"
      source = {
        repoURL        = var.gitops_repo_url
        targetRevision = var.gitops_target_revision
        path           = each.value
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = var.app_namespace
      }
      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
        syncOptions = ["CreateNamespace=true"]
      }
    }
  })

  depends_on = [helm_release.argocd]
}

# App-of-apps for the platform layer (Fase 4: observability). The
# "platform/apps" directory of the GitOps repo holds one ArgoCD Application
# per Helm chart (kube-prometheus-stack, Loki, OpenTelemetry Collector) plus
# the observability config (dashboards). Adding a new platform component is
# just a commit in the GitOps repo.
resource "kubectl_manifest" "platform" {
  yaml_body = yamlencode({
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "platform"
      namespace = kubernetes_namespace.argocd.metadata[0].name
    }
    spec = {
      project = "default"
      source = {
        repoURL        = var.gitops_repo_url
        targetRevision = var.gitops_target_revision
        path           = var.platform_path
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = kubernetes_namespace.argocd.metadata[0].name
      }
      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
      }
    }
  })

  depends_on = [helm_release.argocd]
}

terraform {
  required_providers {
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.14"
    }
  }
}

locals {
  service_account_name = "external-secrets"
}

# EKS Pod Identity: lets the external-secrets pod assume this role, with no
# static AWS access keys stored in the cluster (see the association below).
data "aws_iam_policy_document" "assume_role" {
  statement {
    actions = ["sts:AssumeRole", "sts:TagSession"]

    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "this" {
  name               = "${var.project_name}-external-secrets"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

data "aws_iam_policy_document" "read_secrets" {
  statement {
    actions   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
    resources = var.secret_arns
  }
}

resource "aws_iam_role_policy" "read_secrets" {
  name   = "read-secrets"
  role   = aws_iam_role.this.id
  policy = data.aws_iam_policy_document.read_secrets.json
}

resource "helm_release" "external_secrets" {
  name             = "external-secrets"
  repository       = "https://charts.external-secrets.io"
  chart            = "external-secrets"
  version          = var.chart_version
  namespace        = var.namespace
  create_namespace = true

  values = [
    yamlencode({
      serviceAccount = {
        name = local.service_account_name
      }
    })
  ]

  # The association must exist before the pod starts, or the pod gets no
  # AWS credentials until it is restarted.
  depends_on = [aws_eks_pod_identity_association.external_secrets]
}

resource "aws_eks_pod_identity_association" "external_secrets" {
  cluster_name    = var.cluster_name
  namespace       = var.namespace
  service_account = local.service_account_name
  role_arn        = aws_iam_role.this.arn
}

# Cluster-wide connection to AWS Secrets Manager, shared by every
# ExternalSecret across all namespaces (auth-service, flag-service, ...).
# Auth is implicit: it uses the Pod Identity role associated with the pod's
# service account above, so no credentials are declared here.
resource "kubectl_manifest" "cluster_secret_store" {
  yaml_body = yamlencode({
    apiVersion = "external-secrets.io/v1beta1"
    kind       = "ClusterSecretStore"
    metadata = {
      name = "aws-secretsmanager"
    }
    spec = {
      provider = {
        aws = {
          service = "SecretsManager"
          region  = var.aws_region
        }
      }
    }
  })

  depends_on = [helm_release.external_secrets]
}

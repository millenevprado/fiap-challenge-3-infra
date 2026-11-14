# Generic EKS Pod Identity role: lets the pods of exactly one
# namespace/service account pair assume this role, with no static AWS
# credentials. The eks-pod-identity-agent add-on hands the credentials to the
# pod, so no IAM OIDC provider is needed (the AWS account blocks creating one).
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
  name               = var.role_name
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

resource "aws_iam_role_policy" "this" {
  name   = "app-permissions"
  role   = aws_iam_role.this.id
  policy = var.policy_json
}

resource "aws_eks_pod_identity_association" "this" {
  cluster_name    = var.cluster_name
  namespace       = var.namespace
  service_account = var.service_account_name
  role_arn        = aws_iam_role.this.arn
}

# Self-healing runbook: Grafana alert -> webhook -> this Lambda ->
# `kubectl rollout restart deployment/<name>` on the EKS cluster.

data "archive_file" "lambda" {
  type        = "zip"
  source_file = "${path.module}/src/handler.py"
  output_path = "${path.module}/build/self_healing.zip"
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "this" {
  name               = "${var.project_name}-self-healing"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

resource "aws_iam_role_policy_attachment" "logs" {
  role       = aws_iam_role.this.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Only reads its own secret (webhook token + Slack URL). Kubernetes access is
# NOT granted through IAM policies but through the EKS access entry below.
data "aws_iam_policy_document" "secret" {
  statement {
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [var.secret_arn]
  }
}

resource "aws_iam_role_policy" "secret" {
  name   = "read-observability-secret"
  role   = aws_iam_role.this.id
  policy = data.aws_iam_policy_document.secret.json
}

resource "aws_cloudwatch_log_group" "this" {
  name              = "/aws/lambda/${var.project_name}-self-healing"
  retention_in_days = 14
}

resource "aws_lambda_function" "this" {
  #checkov:skip=CKV_AWS_117:Calls the public EKS endpoint, no VPC resources needed
  #checkov:skip=CKV_AWS_116:Synchronous invocation from Grafana, a DLQ does not apply
  #checkov:skip=CKV_AWS_272:Code signing is out of scope for this challenge
  #checkov:skip=CKV_AWS_173:Env vars hold no secrets (they live in Secrets Manager)
  function_name    = "${var.project_name}-self-healing"
  role             = aws_iam_role.this.arn
  runtime          = "python3.12"
  handler          = "handler.lambda_handler"
  filename         = data.archive_file.lambda.output_path
  source_code_hash = data.archive_file.lambda.output_base64sha256
  timeout          = 180
  memory_size      = 256

  # No reserved_concurrent_executions: new accounts have a concurrency quota
  # of 10, all of it must stay unreserved. Repeated alerts are handled by the
  # cooldown check in the handler instead.

  tracing_config {
    mode = "Active"
  }

  environment {
    variables = {
      CLUSTER_NAME        = var.cluster_name
      CLUSTER_ENDPOINT    = var.cluster_endpoint
      CLUSTER_CA          = var.cluster_ca_data
      SECRET_ARN          = var.secret_arn
      DEFAULT_NAMESPACE   = var.namespace
      ALLOWED_DEPLOYMENTS = join(",", var.allowed_deployments)
      COOLDOWN_SECONDS    = tostring(var.cooldown_seconds)
    }
  }

  depends_on = [aws_cloudwatch_log_group.this, aws_iam_role_policy_attachment.logs]
}

# Public HTTPS endpoint Grafana calls. Authentication is done in the handler
# (Bearer token stored in Secrets Manager, compared in constant time), since
# Grafana's webhook can't sign requests with SigV4 (AWS_IAM auth).
resource "aws_lambda_function_url" "this" {
  #checkov:skip=CKV_AWS_258:Grafana can't SigV4-sign; requests are authenticated with a bearer token in the handler
  function_name      = aws_lambda_function.this.function_name
  authorization_type = "NONE"
}

# A NONE-auth function URL still needs a resource policy allowing public
# calls (the console adds it automatically, the API does not). Since Oct/2025
# Lambda also requires lambda:InvokeFunction scoped to function URL calls.
resource "aws_lambda_permission" "url" {
  statement_id           = "FunctionURLAllowPublicAccess"
  action                 = "lambda:InvokeFunctionUrl"
  function_name          = aws_lambda_function.this.function_name
  principal              = "*"
  function_url_auth_type = "NONE"
}

resource "aws_lambda_permission" "url_invoke" {
  statement_id             = "FunctionURLAllowInvokeAction"
  action                   = "lambda:InvokeFunction"
  function_name            = aws_lambda_function.this.function_name
  principal                = "*"
  invoked_via_function_url = true
}

# Kubernetes RBAC for the Lambda: "edit" ClusterRole-equivalent, scoped to the
# application namespace only (can patch Deployments there, nothing else).
resource "aws_eks_access_entry" "this" {
  cluster_name  = var.cluster_name
  principal_arn = aws_iam_role.this.arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "this" {
  cluster_name  = var.cluster_name
  principal_arn = aws_iam_role.this.arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSEditPolicy"

  access_scope {
    type       = "namespace"
    namespaces = [var.namespace]
  }

  depends_on = [aws_eks_access_entry.this]
}

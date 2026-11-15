module "networking" {
  source = "./modules/networking"

  project_name         = var.project_name
  vpc_cidr             = var.vpc_cidr
  azs                  = var.azs
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
}

module "eks" {
  source = "./modules/eks"

  project_name       = var.project_name
  cluster_name       = "${var.project_name}-eks"
  kubernetes_version = var.eks_cluster_version

  cluster_subnet_ids = concat(module.networking.public_subnet_ids, module.networking.private_subnet_ids)
  node_subnet_ids    = module.networking.private_subnet_ids

  node_instance_types = var.node_instance_types
  node_desired_size   = var.node_desired_size
  node_min_size       = var.node_min_size
  node_max_size       = var.node_max_size
}

module "data_layer" {
  source = "./modules/data_layer"

  project_name                  = var.project_name
  vpc_id                        = module.networking.vpc_id
  eks_cluster_security_group_id = module.eks.cluster_security_group_id
  private_subnet_ids            = module.networking.private_subnet_ids
}

module "rds_auth" {
  source = "./modules/rds"

  identifier             = "${var.project_name}-auth-db"
  db_name                = "authdb"
  engine_version         = var.rds_engine_version
  instance_class         = var.rds_instance_class
  allocated_storage      = var.rds_allocated_storage
  subnet_group_name      = module.data_layer.db_subnet_group_name
  vpc_security_group_ids = [module.data_layer.security_group_id]
  db_user                = var.db_user
  db_pass                = var.db_pass
}

module "rds_flag" {
  source = "./modules/rds"

  identifier             = "${var.project_name}-flag-db"
  db_name                = "flagdb"
  engine_version         = var.rds_engine_version
  instance_class         = var.rds_instance_class
  allocated_storage      = var.rds_allocated_storage
  subnet_group_name      = module.data_layer.db_subnet_group_name
  vpc_security_group_ids = [module.data_layer.security_group_id]
  db_user                = var.db_user
  db_pass                = var.db_pass
}

module "rds_targeting" {
  source = "./modules/rds"

  identifier             = "${var.project_name}-targeting-db"
  db_name                = "targetingdb"
  engine_version         = var.rds_engine_version
  instance_class         = var.rds_instance_class
  allocated_storage      = var.rds_allocated_storage
  subnet_group_name      = module.data_layer.db_subnet_group_name
  vpc_security_group_ids = [module.data_layer.security_group_id]
  db_user                = var.db_user
  db_pass                = var.db_pass
}

# auth-service's JWT signing key — generated once by Terraform and read by
# External Secrets Operator
resource "random_password" "auth_master_key" {
  length  = 32
  special = false
}

resource "aws_secretsmanager_secret" "auth_master_key" {
  name = "${var.project_name}-auth-master-key"
}

resource "aws_secretsmanager_secret_version" "auth_master_key" {
  secret_id     = aws_secretsmanager_secret.auth_master_key.id
  secret_string = random_password.auth_master_key.result
}

# Internal API key evaluation-service uses to call flag-service/targeting-service
# (they authenticate every request against auth-service's /validate). The
# plaintext lives only in Secrets Manager; auth-service's database only ever
# gets the SHA-256 hash, exactly like a key created through its own API.
resource "random_id" "service_api_key" {
  byte_length = 32
}

locals {
  service_api_key      = "tm_key_${random_id.service_api_key.hex}"
  service_api_key_hash = sha256(local.service_api_key)
}

resource "aws_secretsmanager_secret" "service_api_key" {
  name = "${var.project_name}-service-api-key"
}

resource "aws_secretsmanager_secret_version" "service_api_key" {
  secret_id     = aws_secretsmanager_secret.service_api_key.id
  secret_string = local.service_api_key
}

module "elasticache" {
  source = "./modules/elasticache"

  cluster_id             = "${var.project_name}-redis"
  node_type              = var.redis_node_type
  subnet_ids             = module.networking.private_subnet_ids
  vpc_security_group_ids = [module.data_layer.security_group_id]
}

module "dynamodb" {
  source = "./modules/dynamodb"

  table_name = "ToggleMasterAnalytics"
}

module "sqs" {
  source = "./modules/sqs"

  queue_name = "${var.project_name}-evaluation-events"
}

module "ecr" {
  source = "./modules/ecr"

  repository_names = var.ecr_repository_names
}

module "argocd" {
  source = "./modules/argocd"

  chart_version          = var.argocd_chart_version
  gitops_repo_url        = var.gitops_repo_url
  gitops_target_revision = var.gitops_target_revision
  microservices          = var.microservices

  depends_on = [module.eks]
}

module "external_secrets" {
  source = "./modules/external-secrets"

  project_name = var.project_name
  aws_region   = var.aws_region
  cluster_name = module.eks.cluster_name

  secret_arns = [
    module.rds_auth.secret_arn,
    module.rds_flag.secret_arn,
    module.rds_targeting.secret_arn,
    aws_secretsmanager_secret.service_api_key.arn,
    aws_secretsmanager_secret.auth_master_key.arn,
    aws_secretsmanager_secret.observability.arn,
  ]

  depends_on = [module.eks]
}

# evaluation-service only publishes evaluation events to SQS.
data "aws_iam_policy_document" "evaluation_service" {
  statement {
    actions   = ["sqs:SendMessage"]
    resources = [module.sqs.queue_arn]
  }
}

module "pod_identity_evaluation_service" {
  source = "./modules/pod-identity"

  role_name            = "${var.project_name}-evaluation-service"
  cluster_name         = module.eks.cluster_name
  namespace            = "togglemaster"
  service_account_name = "evaluation-service"
  policy_json          = data.aws_iam_policy_document.evaluation_service.json

  depends_on = [module.eks]
}

# analytics-service consumes the same queue and writes the resulting rows to
# DynamoDB.
data "aws_iam_policy_document" "analytics_service" {
  statement {
    actions   = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes"]
    resources = [module.sqs.queue_arn]
  }

  statement {
    actions   = ["dynamodb:PutItem"]
    resources = [module.dynamodb.arn]
  }
}

module "pod_identity_analytics_service" {
  source = "./modules/pod-identity"

  role_name            = "${var.project_name}-analytics-service"
  cluster_name         = module.eks.cluster_name
  namespace            = "togglemaster"
  service_account_name = "analytics-service"
  policy_json          = data.aws_iam_policy_document.analytics_service.json

  depends_on = [module.eks]
}

# Every credential the observability stack needs, in one Secrets Manager
# secret. External Secrets Operator materializes it in the cluster (gitops
# repo: platform/observability/externalsecrets.yaml), so the GitOps repo never
# holds a token in plain text.
resource "random_password" "grafana_admin" {
  length  = 24
  special = false
}

resource "aws_secretsmanager_secret" "observability" {
  name = "${var.project_name}-observability"
}

resource "aws_secretsmanager_secret_version" "observability" {
  secret_id = aws_secretsmanager_secret.observability.id
  secret_string = jsonencode({
    newrelic_license_key   = var.newrelic_license_key
    newrelic_otlp_endpoint = var.newrelic_otlp_endpoint
    pagerduty_routing_key  = var.pagerduty_routing_key
    slack_webhook_url      = var.slack_webhook_url
    grafana_admin_user     = "admin"
    grafana_admin_password = random_password.grafana_admin.result
  })
}

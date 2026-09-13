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

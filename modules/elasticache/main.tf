resource "aws_elasticache_subnet_group" "sg" {
  name       = "${var.cluster_id}-subnet-group"
  subnet_ids = var.subnet_ids
}

resource "aws_elasticache_cluster" "cluster" {
  cluster_id         = var.cluster_id
  engine             = "redis"
  engine_version     = "7.1"
  node_type          = var.node_type
  num_cache_nodes    = 1
  port               = 6379
  subnet_group_name  = aws_elasticache_subnet_group.sg.name
  security_group_ids = var.vpc_security_group_ids

  tags = {
    Name = var.cluster_id
  }
}

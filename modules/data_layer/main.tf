resource "aws_security_group" "data_layer" {
  name        = "${var.project_name}-data-layer-sg"
  description = "Access to the databases only from the EKS cluster"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Postgres/Redis from EKS nodes"
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [var.eks_cluster_security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = var.private_subnet_ids
}

resource "aws_db_instance" "postgres" {
  identifier        = var.identifier
  engine            = "postgres"
  engine_version    = var.engine_version
  instance_class    = var.instance_class
  allocated_storage = var.allocated_storage

  db_name  = var.db_name
  username = var.db_user
  password = var.db_pass

  db_subnet_group_name   = var.subnet_group_name
  vpc_security_group_ids = var.vpc_security_group_ids

  publicly_accessible = false
  skip_final_snapshot = true

  tags = {
    Name = var.identifier
  }
}

# Real credentials, readable by the cluster via External Secrets Operator +
# IRSA
resource "aws_secretsmanager_secret" "credentials" {
  name = "${var.identifier}-credentials"
}

resource "aws_secretsmanager_secret_version" "credentials" {
  secret_id = aws_secretsmanager_secret.credentials.id
  secret_string = jsonencode({
    username = var.db_user
    password = var.db_pass
    host     = aws_db_instance.postgres.address
    port     = tostring(aws_db_instance.postgres.port)
    dbname   = var.db_name
  })
}

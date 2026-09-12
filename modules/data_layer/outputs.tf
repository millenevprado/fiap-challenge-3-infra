output "security_group_id" {
  value = aws_security_group.data_layer.id
}

output "db_subnet_group_name" {
  value = aws_db_subnet_group.main.name
}

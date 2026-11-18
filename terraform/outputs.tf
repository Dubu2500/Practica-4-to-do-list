output "ec2_public_ip" {
  description = "IP publica de la EC2"
  value       = aws_instance.todo.public_ip
}

output "instance_id" {
  description = "ID de la EC2, se usa en las alarmas y el dashboard"
  value       = aws_instance.todo.id
}

output "rds_endpoint" {
  description = "Endpoint de la base de datos"
  value       = aws_db_instance.todo.address
}

output "secret_name" {
  description = "Nombre del secret con las credenciales"
  value       = aws_secretsmanager_secret.db.name
}

output "api_url" {
  description = "URL de la API"
  value       = "http://${aws_instance.todo.public_ip}:8000"
}

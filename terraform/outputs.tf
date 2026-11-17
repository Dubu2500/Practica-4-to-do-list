output "ec2_public_ip" {
  description = "IP publica de la EC2"
  value       = aws_instance.todo.public_ip
}

output "api_url" {
  description = "URL de la API"
  value       = "http://${aws_instance.todo.public_ip}:8000"
}

variable "region" {
  type        = string
  description = "Region de AWS"
  default     = "us-east-1"
}

variable "repo_url" {
  type        = string
  description = "Repositorio que clona la EC2 al arrancar"
  default     = "https://github.com/Dubu2500/Practica-4-to-do-list.git"
}

variable "secret_name" {
  type        = string
  description = "Nombre del secret con las credenciales de RDS"
  default     = "todo/db-credentials"
}

variable "public_key" {
  type        = string
  description = "Llave publica SSH para el key pair (contenido de todo-key.pub)"
}

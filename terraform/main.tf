terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }

  backend "s3" {
    bucket = "todo-list-tfstate-dubu2500"
    key    = "todo/terraform.tfstate"
    region = "us-east-1"
  }
}

provider "aws" {
  region = var.region
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd*/ubuntu-*-amd64-server-*"]
  }
}

resource "aws_key_pair" "todo" {
  key_name   = "todo-key"
  public_key = var.public_key
}

resource "aws_security_group" "ec2" {
  name        = "todo-ec2-sg"
  description = "SG para EC2 de to-do-list-api"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "db" {
  name        = "todo-db-sg"
  description = "SG para RDS de to-do-list-api"

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2.id]
  }
}

resource "random_password" "db" {
  length  = 16
  special = false
}

resource "aws_db_instance" "todo" {
  identifier             = "todo-db"
  engine                 = "postgres"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  db_name                = "todo"
  username               = "todo_admin"
  password               = random_password.db.result
  vpc_security_group_ids = [aws_security_group.db.id]
  skip_final_snapshot    = true
}

resource "aws_secretsmanager_secret" "db" {
  name                    = var.secret_name
  recovery_window_in_days = 0 # permite recrearlo con el mismo nombre
}

resource "aws_secretsmanager_secret_version" "db" {
  secret_id = aws_secretsmanager_secret.db.id
  secret_string = jsonencode({
    host     = aws_db_instance.todo.address
    port     = aws_db_instance.todo.port
    dbname   = aws_db_instance.todo.db_name
    username = aws_db_instance.todo.username
    password = random_password.db.result
  })
}

resource "aws_instance" "todo" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.micro"
  key_name               = aws_key_pair.todo.key_name
  vpc_security_group_ids = [aws_security_group.ec2.id]

  # learner lab no permite crear roles
  iam_instance_profile = "LabInstanceProfile"

  user_data = templatefile("${path.module}/user_data.sh", {
    repo_url    = var.repo_url
    secret_name = var.secret_name
    region      = var.region
  })

  depends_on = [aws_secretsmanager_secret_version.db]

  tags = {
    Name = "todo-list-api"
  }
}

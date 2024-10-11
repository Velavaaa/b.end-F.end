provider "aws" {
  region = "us-east-1"
}

resource "aws_instance" "app_server" {
  ami           = "ami-0866a3c8686eaeeba"  # Example AMI ID for Ubuntu Server 20.04 LTS
  instance_type = "t2.micro"
  key_name      = "bb"

  user_data = <<-EOF
              #!/bin/bash
              apt-get update -y
              apt-get install docker.io -y
              service docker start
              docker pull indhura/backend_app_image
              docker run -d -p 8080:8080 -e DB_HOST=${aws_db_instance.postgres.endpoint} -e DB_PASSWORD=${var.db_password} indhura/backend_app_image
              EOF

  tags = {
    Name = "BackendServer"
  }
}

resource "aws_security_group" "allow_http" {
  name_prefix = "allow_http"
  description = "Allow HTTP traffic"

  ingress {
    from_port   = 80
    to_port     = 80
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

resource "aws_db_instance" "postgres" {
  identifier             = "mydb-terraform"  # Use hyphen instead of underscore
  allocated_storage      = 20
  engine                 = "postgres"
  engine_version         = "13.11"
  instance_class         = "db.t3.micro"
  username               = "db_admin"
  password               = var.db_password
  skip_final_snapshot    = true
  publicly_accessible    = false
  vpc_security_group_ids = [aws_security_group.allow_http.id]
}

output "app_server_public_ip" {
  value = aws_instance.app_server.public_ip
}

output "db_endpoint" {
  value = aws_db_instance.postgres.endpoint
}

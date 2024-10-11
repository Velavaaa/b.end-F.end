Step 1: Set Up Your Environment
Install Terraform: Follow the installation instructions for your operating system.

Configure AWS CLI:aws configure


Enter your AWS credentials and region.

Step 2: Create the Backend Application
Write a simple Python Flask app:
app.py:
from flask import Flask, jsonify
import psycopg2

app = Flask(__name__)

@app.route('/hello', methods=['GET'])
def hello_world():
    return jsonify(message="Hello, World!")

@app.route('/data', methods=['GET'])
def get_data():
    conn = psycopg2.connect(
        dbname='mydb',
        user='admin',
        password='your_db_password',
        host='your_db_host',
        port='5432'
    )
    cur = conn.cursor()
    cur.execute("SELECT * FROM your_table")
    data = cur.fetchall()
    conn.close()
    return jsonify(data)

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080)
2.Dockerize your backend application:

Dockerfile:
FROM python:3.8-slim

WORKDIR /app

COPY requirements.txt requirements.txt
RUN pip install -r requirements.txt

COPY . .

CMD ["python", "app.py"]

requirements.txt:
Flask
psycopg2-binary


Step 3: Deploy the Backend and Database Using Terraform
Create a new directory:
mkdir terraform_backend
cd terraform_backend

Create Terraform configuration files:

main.tf:
provider "aws" {
  region = "us-east-1"
}

resource "aws_instance" "app_server" {
  ami           = "ami-0c55b159cbfafe1f0"  # Example AMI ID for Ubuntu Server 20.04 LTS
  instance_type = "t2.micro"
  key_name      = "your_key_pair"

  user_data = <<-EOF
              #!/bin/bash
              apt-get update -y
              apt-get install docker.io -y
              service docker start
              docker pull your_dockerhub_username/backend_app_image
              docker run -d -p 8080:8080 -e DB_HOST=${aws_db_instance.postgres.endpoint} -e DB_PASSWORD=${var.db_password} your_dockerhub_username/backend_app_image
              EOF

  tags = {
    Name = "BackendServer"
  }
}

resource "aws_security_group" "allow_http" {
  name        = "allow_http"
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
  identifier             = "mydb"
  allocated_storage      = 20
  engine                 = "postgres"
  instance_class         = "db.t2.micro"
  username               = "admin"
  password               = var.db_password
  skip_final_snapshot    = true
}

output "app_server_public_ip" {
  value = aws_instance.app_server.public_ip
}

output "db_endpoint" {
  value = aws_db_instance.postgres.endpoint
}

variables.tf:
variable "db_password" {
  description = "Password for the PostgreSQL database"
  type        = string
}

Initialize and Apply Terraform:

Initialize Terraform:
terraform init

terraform plan -var="db_password=your_db_password"
terraform apply -var="db_password=your_db_password"



Step 4: Deploy the Frontend Using Terraform
Build Your React App:

Navigate to your React project directory and run:
npm install
npm run build


Create Terraform configuration for frontend:

frontend.tf:
provider "aws" {
  region = "us-east-1"
}

resource "aws_s3_bucket" "react_app_bucket" {
  bucket = "my-react-app-bucket"
  acl    = "public-read"
}

resource "aws_s3_bucket_object" "react_app_files" {
  for_each = fileset("./build", "**")
  bucket   = aws_s3_bucket.react_app_bucket.bucket
  key      = each.value
  source   = "./build/${each.value}"
  etag     = filemd5("./build/${each.value}")
}

resource "aws_cloudfront_distribution" "react_app_distribution" {
  origin {
    domain_name = aws_s3_bucket.react_app_bucket.bucket_regional_domain_name
    origin_id   = aws_s3_bucket.react_app_bucket.id

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.react_app_identity.cloudfront_access_identity_path
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "React Frontend Application"
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = aws_s3_bucket.react_app_bucket.id

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  depends_on = [aws_s3_bucket.react_app_bucket]
}

resource "aws_cloudfront_origin_access_identity" "react_app_identity" {
  comment = "React App Origin Access Identity"
}

output "cloudfront_domain_name" {
  value = aws_cloudfront_distribution.react_app_distribution.domain_name
}


terraform init

terraform plan

terraform apply



Step 5: Connecting Frontend with Backend
Update your React app to call the backend API.

Example React App Code:

fetch('http://<backend_server_public_ip>:8080/data')
  .then(response => response.json())
  .then(data => console.log(data))
  .catch(error => console.error('Error:', error));


Step 6: Testing the Full Stack
Backend Test:

Open your browser and access http://<backend_server_public_ip>:8080/hello to verify the backend.

Frontend Test:

Open your browser and go to the CloudFront URL to access your React frontend.

Ensure the frontend is making API calls to the backend and displaying data

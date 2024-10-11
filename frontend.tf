provider "aws" {
  region = "ap-northeast-2"  # Ensure this matches your actual region
}

# Create an S3 bucket for the React app
resource "aws_s3_bucket" "react_app_bucket" {
  bucket        = "my-unique-react-app-bucket-12345"  # Ensure bucket name is globally unique and follows naming rules
  force_destroy = true  # Ensures the bucket and all its contents are destroyed
}

# Use a bucket policy instead of ACLs to control access
resource "aws_s3_bucket_policy" "react_app_bucket_policy" {
  bucket = aws_s3_bucket.react_app_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "cloudfront.amazonaws.com"
      }
      Action = "s3:GetObject"
      Resource = "${aws_s3_bucket.react_app_bucket.arn}/*"
    }]
  })
}

# Upload React app files to the S3 bucket (use aws_s3_object instead of aws_s3_bucket_object)
resource "aws_s3_object" "react_app_files" {
  for_each = fileset("../build", "**")
  bucket   = aws_s3_bucket.react_app_bucket.bucket
  key      = each.value
  source   = "../build/${each.value}"
  etag     = filemd5("../build/${each.value}")
}

# Create a CloudFront distribution for the React app
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

  depends_on = [aws_s3_bucket.react_app_bucket, aws_s3_bucket_policy.react_app_bucket_policy]
}

# Create an Origin Access Identity (OAI) to allow CloudFront to access the S3 bucket
resource "aws_cloudfront_origin_access_identity" "react_app_identity" {
  comment = "React App Origin Access Identity"
}

# Output the CloudFront domain name for the React app
output "cloudfront_domain_name" {
  value = aws_cloudfront_distribution.react_app_distribution.domain_name
}

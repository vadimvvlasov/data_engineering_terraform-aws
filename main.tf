# AWS Provider configuration
terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region  = var.region
  profile = "dtc"
}

# S3 bucket — equivalent of GCS bucket
resource "aws_s3_bucket" "my_bucket" {
  bucket        = var.bucket_name     # bucket name must be globally unique
  force_destroy = true                # allows deletion even if bucket is not empty
}

# Versioning — keeps multiple versions of each object
resource "aws_s3_bucket_versioning" "versioning" {
  bucket = aws_s3_bucket.my_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Lifecycle rule — delete noncurrent object versions after 7 days (similar to GCS lifecycle)
resource "aws_s3_bucket_lifecycle_configuration" "lifecycle" {
  bucket     = aws_s3_bucket.my_bucket.id
  depends_on = [aws_s3_bucket_versioning.versioning]

  rule {
    id     = "expire-old-versions"
    status = "Enabled"

    filter {} # applies to all objects in the bucket

    noncurrent_version_expiration {
      noncurrent_days = 7
    }
  }
}

# Block all public access (explicitly enforced, even though it is the default)
resource "aws_s3_bucket_public_access_block" "block_public" {
  bucket = aws_s3_bucket.my_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

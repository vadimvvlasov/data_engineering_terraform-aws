# Провайдер AWS
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

# S3 бакет — аналог GCS bucket из видео
resource "aws_s3_bucket" "my_bucket" {
  bucket        = var.bucket_name     # имя бакета должно быть глобально уникальным
  force_destroy = true
}

# Управление версионированием (в видео Storage Class и lifecycle)
resource "aws_s3_bucket_versioning" "versioning" {
  bucket = aws_s3_bucket.my_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Жизненный цикл: удалять старые версии объектов через 7 дней (как в GCS lifecycle)
resource "aws_s3_bucket_lifecycle_configuration" "lifecycle" {
  bucket     = aws_s3_bucket.my_bucket.id
  depends_on = [aws_s3_bucket_versioning.versioning]

  rule {
    id     = "expire-old-versions"
    status = "Enabled"

    filter {} # применяется ко всем объектам в бакете

    noncurrent_version_expiration {
      noncurrent_days = 1
    }
  }
}

# Блокировка публичного доступа (по умолчанию включена, но зафиксируем явно)
resource "aws_s3_bucket_public_access_block" "block_public" {
  bucket = aws_s3_bucket.my_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
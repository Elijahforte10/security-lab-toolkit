# example_secure_s3.tf — a deliberately *secure* Terraform example
#
# Demonstrates the IaC security concepts: encryption at rest, blocking
# public access, versioning for repeatable/recoverable state, and no
# hardcoded secrets. Use this as a "known good" file to confirm your
# iac_security_scan.sh pipeline passes clean resources and flags bad ones.
#
# (Conceptual reference — adjust provider/region/names for your environment.)

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

variable "region" {
  type    = string
  default = "us-east-1"
}

variable "bucket_name" {
  type        = string
  description = "Globally unique bucket name"
}

resource "aws_s3_bucket" "secure" {
  bucket = var.bucket_name

  tags = {
    ManagedBy = "Terraform"
    Purpose   = "iac-security-demo"
  }
}

# Versioning -> repeatable deployment + recoverability (drift/rollback)
resource "aws_s3_bucket_versioning" "secure" {
  bucket = aws_s3_bucket.secure.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Encryption at rest
resource "aws_s3_bucket_server_side_encryption_configuration" "secure" {
  bucket = aws_s3_bucket.secure.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

# Block ALL public access — the single most common S3 misconfiguration
resource "aws_s3_bucket_public_access_block" "secure" {
  bucket                  = aws_s3_bucket.secure.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

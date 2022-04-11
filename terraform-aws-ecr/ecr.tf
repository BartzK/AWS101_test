terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "4.8.0"
    }
  }
}

provider "aws" {
  profile = "default"
  region  = "eu-central-1"
}

variable "vpc_id" {
  type    = string
  default = "vpc-0fead40e24304ce5f"
}

variable "user_prefix" {
  type    = string
  default = "bk"
}

resource "aws_ecr_repository" "ecr" {
  name = "${var.user_prefix}-repository"
}

resource "aws_ecr_repository_policy" "bk-repo-policy" {
  repository = aws_ecr_repository.aws101-repository.name
  policy     = <<EOF
  {
    "Version": "2008-10-17",
    "Statement": [
      {
        "Sid": "adds full ecr access to the aws101 repository",
        "Effect": "Allow",
        "Principal": "*",
        "Action": [
          "ecr:BatchCheckLayerAvailability",
          "ecr:BatchGetImage",
          "ecr:CompleteLayerUpload",
          "ecr:GetDownloadUrlForLayer",
          "ecr:GetLifecyclePolicy",
          "ecr:InitiateLayerUpload",
          "ecr:PutImage",
          "ecr:UploadLayerPart"
        ]
      }
    ]
  }
  EOF
}
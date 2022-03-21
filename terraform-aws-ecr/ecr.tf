terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.27"
    }
  }

  required_version = ">= 0.14.9"
}

provider "aws" {
  profile = "default"
  region  = "us-east-1"
}

resource "aws_ecr_repository" "aws101-repository" {
  name                 = "aws101-repo"
  image_tag_mutability = "IMMUTABLE"
}

resource "aws_ecr_repository_policy" "aws101-repo-policy" {
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
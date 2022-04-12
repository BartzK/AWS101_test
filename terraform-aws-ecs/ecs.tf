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

data "aws_vpc" "vpc" {
  id = var.vpc_id
}

resource "aws_ecr_repository" "ecr" {
  name = "${var.user_prefix}-repository"
}

resource "aws_ecr_repository_policy" "repo-policy" {
  repository = aws_ecr_repository.ecr.name
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

resource "aws_iam_role" "ecsTaskExecutionRole" {
  name               = "${var.user_prefix}-execution-task-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json
}

data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "ecsTaskExecutionRole_policy" {
  role       = aws_iam_role.ecsTaskExecutionRole.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_instance_profile" "instance_profile" {
  name = "bk-instance-profile"
  role = aws_iam_role.ecsTaskExecutionRole.name
}

resource "aws_instance" "app_server" {
    ami                          = "ami-0143f2b57717ab830"
    associate_public_ip_address  = true
    instance_type                = "t2.micro"
	iam_instance_profile         = aws_iam_instance_profile.instance_profile.name
    tags                         = {
        "Name" = "bk-instance"
    }
	
	user_data = <<EOF
	#!/bin/bash
	echo ECS_CLUSTER=${aws_ecs_cluster.ecs-cluster.name} >> /ets/ecs/ecs.config
	EOF

}

resource "aws_ecs_cluster" "ecs-cluster" {
  name = "${var.user_prefix}-ecs-cluster"
  setting {
    name = "containerInsights"
	value = "enabled"
  }
}

resource "aws_ecs_task_definition" "ecs-task-definition" {
  family                   = "${var.user_prefix}-definition"
  network_mode             = "awsvpc"
  requires_compatibilities = ["EC2"]
  memory                   = "256"
  cpu                      = "256"
  execution_role_arn       = aws_iam_role.ecsTaskExecutionRole.arn
  task_role_arn            = aws_iam_role.ecsTaskExecutionRole.arn
  container_definitions    = <<DEFINITION
  [
    {
      "name": "${var.user_prefix}-container",
      "image": "${aws_ecr_repository.ecr.repository_url}/${var.user_prefix}-repository:latest",
      "memory": 256,
      "cpu": 256,
      "networkMode": "awsvpc",
      "essential": true,
      "portMappings": [
        {
          "containerPort": 80,
          "hostPort": 80
        },
        {
          "containerPort": 443,
          "hostPort": 443
        }
      ]
    }
  ]
  DEFINITION
}

resource "aws_ecs_service" "ecs-service" {
  name            = "${var.user_prefix}-service"
  cluster         = aws_ecs_cluster.ecs-cluster.id
  task_definition = aws_ecs_task_definition.ecs-task-definition.arn
  launch_type     = "EC2"
  desired_count   = 1
  
  network_configuration {
    subnets        = ["subnet-020c346673e0afe4f"]
    security_groups = ["sg-0f7ef34ae71da89ef"]
  }
}
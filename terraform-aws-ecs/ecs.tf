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

resource "aws_ecs_cluster" "ecs-cluster" {
  name = "${var.user_prefix}-cluster"
}

resource "aws_ecs_cluster_capacity_providers" "ecs-cluster" {
  cluster_name = aws_ecs_cluster.ecs.name

  capacity_providers = ["EC2"]

  default_capacity_provider_strategy {
    base              = 1
    weight            = 10
    capacity_provider = "EC2"
  }
}

resource "aws_instance" "app_server" {
    ami                          = "ami-830c94e3"
    associate_public_ip_address  = true
    instance_type                = "t2.micro"
    tags                         = {
        "Name" = "bk-instance"
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
  desired_count = 1
}


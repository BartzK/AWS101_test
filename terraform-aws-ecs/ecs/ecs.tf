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

resource "aws_ecs_cluster" "aws101-ecs-cluster" {
  name = "ecs-cluster-for-aws101"
}

resource "aws_ecs_service" "aws101-ecs-service-two" {
  name            = "aws101-app"
  cluster         = aws_ecs_cluster.aws101-ecs-cluster.id
  task_definition = aws_ecs_task_definition.aws101-ecs-task-definition.arn
  launch_type     = "FARGATE"
  network_configuration {
    subnets          = ["subnet-05t93f90b22ba76qx"]
    assign_public_ip = true
  }
  desired_count = 1
}

resource "aws_ecs_task_definition" "aws101-ecs-task-definition" {
  family                   = "ecs-task-definition-aws101"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  memory                   = "1024"
  cpu                      = "512"
  execution_role_arn       = "arn:aws:iam::123456789012:role/ecsTaskExecutionRole"
  container_definitions    = <<EOF
[
  {
    "name": "aws101-container",
    "image": "281738164247.dkr.ecr.us-east-1.amazonaws.com/aws101-repo:latest",
    "memory": 256,
    "cpu": 256,
    "essential": true,
    "entryPoint": ["/"],
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
EOF
}
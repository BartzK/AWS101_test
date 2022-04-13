terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "4.8.0"
    }
  }
}

provider "aws" {
  region  = "eu-central-1"
}

variable "vpc_id" {
  type    = string
  default = "vpc-0fead40e24304ce5f"
}

variable "subnet_id" {
  type    = string
  default = "subnet-0c5ab4a1499db9f85"
}

variable "user_prefix" {
  type    = string
  default = "bk"
}

data "aws_vpc" "vpc" {
  id = var.vpc_id
}

data "aws_subnet" "snet" {
  id = var.subnet_id
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

resource "aws_security_group" "bk-security-group" {
  vpc_id = data.aws_vpc.vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_iam_role" "ecs-instance-role" {
  name               = "${var.user_prefix}-ecs-role"
  assume_role_policy = data.aws_iam_policy_document.ecs-policy.json
}

resource "aws_iam_role_policy_attachment" "ecsTaskExecutionRole_policy" {
  role       = aws_iam_role.ecs-instance-role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

data "aws_iam_policy_document" "ecs-policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ec2-instance-role" {
  name               = "${var.user_prefix}-ec2-instance-role"
  assume_role_policy = data.aws_iam_policy_document.ec2-policy.json
}

resource "aws_iam_role_policy_attachment" "ec2TaskExecutionRole_policy" {
  role       = aws_iam_role.ec2-instance-role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

data "aws_iam_policy_document" "ec2-policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_instance_profile" "instance_profile" {
  name = "bk-instance-profile"
  role = aws_iam_role.ec2-instance-role.name
}

resource "aws_ecs_cluster" "ecs-cluster" {
  name = "${var.user_prefix}-ecs-cluster"
  setting {
    name = "containerInsights"
	value = "enabled"
  }
}

resource "aws_launch_configuration" "ecs-launch-configuration" {
  name                 = "${var.user_prefix}-launch-configuration"
  image_id             = "ami-0c114f68881dc4f44"
  instance_type        = "t2.micro"
  iam_instance_profile = "${aws_iam_instance_profile.instance_profile.name}"
  key_name = "bk-key-pair"
  security_groups = [aws_security_group.bk-security-group.id]
  associate_public_ip_address = "true"
  user_data                   = <<DEFINITION
#!/bin/bash
echo ECS_CLUSTER=${aws_ecs_cluster.ecs-cluster.name} >> /etc/ecs/ecs.config;
DEFINITION
}

resource "aws_autoscaling_group" "autoscaling_group" {
  name                      = "${var.user_prefix}-autoscaling"
  vpc_zone_identifier  = [data.aws_subnet.snet.id]
  launch_configuration      = aws_launch_configuration.ecs-launch-configuration.name
  min_size                  = 1
  max_size                  = 10
  desired_capacity          = 1
  health_check_type         = "EC2"
  health_check_grace_period = 300
}

resource "aws_ecs_task_definition" "ecs-task-definition" {
  family                   = "${var.user_prefix}-definition"
  memory                   = "512"
  cpu                      = "1vcpu"
  execution_role_arn       = aws_iam_role.ecs-instance-role.arn
  task_role_arn            = aws_iam_role.ecs-instance-role.arn
  container_definitions    = <<DEFINITION
  [
    {
      "name": "${var.user_prefix}-container",
      "image": "${aws_ecr_repository.ecr.repository_url}/${var.user_prefix}-repository:latest",
      "memory": 512,
      "cpu": 1,
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
  enable_ecs_managed_tags = true
}
provider "aws" {
  region = "ap-south-1"
}

#######################
# VPC
#######################

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
}

#######################
# Subnets
#######################

resource "aws_subnet" "public_1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "ap-south-1a"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "public_2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "ap-south-1b"
  map_public_ip_on_launch = true
}

#######################
# Route Table
#######################

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route" "internet_access" {
  route_table_id         = aws_route_table.public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route_table_association" "a1" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "a2" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public_rt.id
}

#######################
# Security Groups
#######################

resource "aws_security_group" "alb_sg" {
  name   = "backend-staging-alb-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "ecs_sg" {
  name   = "backend-staging-ecs-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port       = 5000
    to_port         = 5000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#######################
# Load Balancer
#######################

resource "aws_lb" "alb" {
  name               = "backend-staging-alb"
  load_balancer_type = "application"
  subnets            = [aws_subnet.public_1.id, aws_subnet.public_2.id]
  security_groups    = [aws_security_group.alb_sg.id]
}

resource "aws_lb_target_group" "tg" {
  name        = "backend-staging-tg"
  port        = 5000
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    path                = "/api/health"
    interval            = 30
    timeout             = 10
    healthy_threshold   = 2
    unhealthy_threshold = 5
    matcher             = "200-399"
  }
}

resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }

  depends_on = [aws_lb_target_group.tg]
}

#######################
# ECS Cluster
#######################

resource "aws_ecs_cluster" "cluster" {
  name = "backend-staging-cluster"
}

#######################
# IAM Role for ECS Execution
#######################

resource "aws_iam_role" "ecs_exec_role" {
  name = "ecsTaskExecutionRole-staging"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_exec_policy" {
  role       = aws_iam_role.ecs_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

#######################
# ECS Task Definition
#######################

resource "aws_ecs_task_definition" "task" {
  family                   = "backend-staging-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_exec_role.arn

  container_definitions = jsonencode([
    {
      name  = "backend"
      image = "314103481823.dkr.ecr.ap-south-1.amazonaws.com/backend-app:latest"
      portMappings = [{
        containerPort = 5000
      }]
      
    }
  ])
}

#######################
# ECS Service
#######################

resource "aws_ecs_service" "service" {
  name            = "backend-staging-service"
  cluster         = aws_ecs_cluster.cluster.id
  task_definition = aws_ecs_task_definition.task.arn
  desired_count   = 2
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [aws_subnet.public_1.id, aws_subnet.public_2.id]
    security_groups  = [aws_security_group.ecs_sg.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.tg.arn
    container_name   = "backend"
    container_port   = 5000
  }

  depends_on = [aws_lb_listener.listener]
}

#######################
# Output
#######################

output "alb_dns_name" {
  value = aws_lb.alb.dns_name
}







#######################
# S3 Bucket - Staging (Private)
#######################
resource "aws_s3_bucket" "frontend_staging" {
  bucket = "pg-agi-frontend-staging"

  # Optional: enable versioning for staging
  versioning {
    enabled = true
  }

  # Ensure block all public access
  acl = "private"
}
#######################
# Website configuration (if needed)
#######################
resource "aws_s3_bucket_website_configuration" "frontend_site" {
  bucket = aws_s3_bucket.frontend_staging.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "index.html"
  }
}

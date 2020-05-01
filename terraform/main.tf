locals {
	//in a larger project we  would want these variables in a separate file 
	name = "hello-world"
	log_name = "hello-log"
	port = 80
	alb_port = 8080
}

//we  could use the default vpc here but will create our own just to be sure
resource "aws_vpc" "vpc" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "public" {
  vpc_id     = aws_vpc.vpc.id
  cidr_block = "10.0.1.0/24"
}

resource "aws_subnet" "private" {
  vpc_id     = aws_vpc.vpc.id
  cidr_block = "10.0.2.0/24"
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.vpc.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.vpc.id
}

resource "aws_route_table_association" "public_subnet" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private_subnet" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}

resource "aws_eip" "nat" {
  vpc = true
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id
}

resource "aws_nat_gateway" "ngw" {
  subnet_id     = aws_subnet.public.id
  allocation_id = aws_eip.nat.id

  depends_on = [
    aws_internet_gateway.igw
  ]
}

resource "aws_route" "public_igw" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route" "private_ngw" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.ngw.id
}

resource "aws_security_group" "http" {
  name        = "http"
  description = "HTTP traffic"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    from_port   = local.alb_port
    to_port     = local.alb_port
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "egress-all" {
  name        = "egress_all"
  description = "Allow all outbound traffic"
  vpc_id      = aws_vpc.vpc.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "service-ingress" {
  name        = "${local.name}-ingress"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    from_port   = local.port
    to_port     = local.port
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_ecs_service" "hello-world" {
  name            = local.name
  task_definition = aws_ecs_task_definition.hello-world.arn
  cluster 	  = aws_ecs_cluster.cluster.id
  launch_type     = "FARGATE"
  desired_count   = 1

  network_configuration {
	assign_public_ip = false

	security_groups = [
		aws_security_group.egress-all.id,
		aws_security_group.http.id,
		aws_security_group.service-ingress.id
	]
	subnets = [
		aws_subnet.private.id
	]
  }

  load_balancer {
	target_group_arn = aws_lb_target_group.hello-world.arn
	container_name = local.name
	container_port = local.port
  }
}

resource "aws_cloudwatch_log_group" "hello-world" {
  name = "/ecs/${local.name}"
}

resource "aws_ecs_cluster" "cluster" {
	name = local.name
}

resource "aws_ecs_task_definition" "hello-world" {
  family = local.name

  container_definitions = <<EOF
  [
    {
      "name": "${local.name}",
      "image": "nginxdemos/hello:latest",
      "portMappings": [
        {
          "containerPort": 80
        }
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-region": "us-east-1",
          "awslogs-group": "/ecs/${local.name}",
          "awslogs-stream-prefix": "ecs"
        }
      }
    }
  ]
  EOF

  execution_role_arn = aws_iam_role.execute.arn
  cpu = 256
  memory = 512
  requires_compatibilities = ["FARGATE"]
  network_mode = "awsvpc"
}

resource "aws_iam_role" "execute" {
  name = "${local.name}-execution-role"
  assume_role_policy = data.aws_iam_policy_document.execute.json
}

data "aws_iam_policy_document" "execute" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

# this is an AWS managed policy, ARN should not change
data "aws_iam_policy" "execute" {
  arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy_attachment" "execute" {
  role = aws_iam_role.execute.name
  policy_arn = data.aws_iam_policy.execute.arn
}

resource "aws_lb_target_group" "hello-world" {
  name = local.name
  port = local.port
  protocol = "HTTP"
  target_type = "ip"
  vpc_id = aws_vpc.vpc.id

  health_check {
    enabled = true
    path = "/health"
  }

  depends_on = [
    aws_alb.hello-world
  ]
}

resource "aws_alb" "hello-world" {
  name = local.name
  internal = false
  load_balancer_type = "application"

  subnets = [
    aws_subnet.public.id,
    aws_subnet.private.id,
  ]

  security_groups = [
    aws_security_group.http.id,
    aws_security_group.egress-all.id,
  ]

  depends_on = [aws_internet_gateway.igw]
}

resource "aws_alb_listener" "hello-world" {
  load_balancer_arn = aws_alb.hello-world.arn
  port = local.alb_port
  protocol = "HTTP"

  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.hello-world.arn
  }
}

resource "aws_flow_log" "log" {
  iam_role_arn    = aws_iam_role.log.arn
  log_destination = aws_cloudwatch_log_group.log.arn
  traffic_type    = "ALL"
  vpc_id          = aws_vpc.vpc.id
}

resource "aws_cloudwatch_log_group" "log" {
  name = local.log_name
}

resource "aws_iam_role" "log" {
  name = local.log_name

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "vpc-flow-logs.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "log" {
  name = local.log_name
  role = aws_iam_role.log.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}

output "alb_endpoint" {
  value = "http://${aws_alb.hello-world.dns_name}:${local.alb_port}"
}

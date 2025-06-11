resource "aws_ecs_cluster" "main" {
  name = "springboot-ecs-cluster"

  configuration {
    execute_command_configuration {
      logging = "DEFAULT" # Or "CLOUDWATCH_LOGS" with additional log config
    }
  }
}

resource "aws_iam_role" "ecs_task_execution" {
  name = "ecsTaskExecutionRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_policy" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy_attachment" "ecs_task_ssm_core" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy" "s3_access" {
  name = "AllowS3Read"
  role = aws_iam_role.ecs_task_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = ["s3:GetObject", "s3:ListBucket"]
        Effect = "Allow"
        Resource = [
          "arn:aws:s3:::${var.aws_s3_bucket_name}",
          "arn:aws:s3:::${var.aws_s3_bucket_name}/*"
        ]
      }
    ]
  })
}

resource "aws_security_group" "ecs" {
  name        = "ecs-service-sg"
  description = "Allow inbound access for ECS services"
  vpc_id      = aws_vpc.springboot.id

  ingress {
    from_port = 8080
    to_port   = 8080
    protocol  = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 8888
    to_port   = 8888
    protocol  = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 9090
    to_port   = 9090
    protocol  = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# resource "aws_security_group_rule" "allow_lambda_to_config_service" {
#   type                     = "ingress"
#   from_port                = 8888
#   to_port                  = 8888
#   protocol                 = "tcp"
#   security_group_id        = aws_security_group.ecs.id              # Config service SG
#   source_security_group_id = aws_security_group.lambda_sg.id        # Lambda SG
#   description              = "Allow Lambda to call /busrefresh on port 8888"
# }



// alb resources here
resource "aws_lb" "main" {
  name               = "springboot-app-lb"
  internal           = false
  load_balancer_type = "application"
  subnets = [aws_subnet.public_az1.id, aws_subnet.public_az2.id]

  security_groups = [aws_security_group.ecs.id]

  tags = {
    Name = "springboot-alb"
  }
}

// alb target group for config service
resource "aws_lb_target_group" "config" {
  name        = "config-tg"
  port        = var.config_service_port
  protocol    = "HTTP"
  vpc_id      = aws_vpc.springboot.id
  target_type = "ip"

  health_check {
    path                = "/actuator/health"
    protocol            = "HTTP"
    healthy_threshold   = 10
    unhealthy_threshold = 10
    timeout             = 10
    interval            = 30
    matcher             = "200"
  }

}

// alb target group for catalog service

resource "aws_lb_target_group" "catalog" {
  name        = "catalog-tg"
  port        = var.catalog_service_port
  protocol    = "HTTP"
  vpc_id      = aws_vpc.springboot.id
  target_type = "ip"

  health_check {
    path                = "/actuator/health"
    protocol            = "HTTP"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200"
  }
}

// alb target group for demo service
resource "aws_lb_target_group" "demoservice" {
  name        = "demoservice-tg"
  port        = var.demo_service_port
  protocol    = "HTTP"
  vpc_id      = aws_vpc.springboot.id
  target_type = "ip"

  health_check {
    path                = "/actuator/health"
    protocol            = "HTTP"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200"
  }
}


// http listener
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = var.catalog_service_port
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.catalog.arn
  }

}


resource "aws_lb_listener_rule" "catalog" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.catalog.arn
  }

  condition {
    path_pattern {
      values = ["/*"]
    }
  }
}

resource "aws_lb_listener" "config" {
  load_balancer_arn = aws_lb.main.arn
  port              = var.config_service_port
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.config.arn
  }
}

resource "aws_lb_listener" "demo" {
  load_balancer_arn = aws_lb.main.arn
  port              = var.demo_service_port
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.demoservice.arn
  }
}




// ecs task definition config service

resource "aws_ecs_task_definition" "config" {
  family             = "config-service"
  requires_compatibilities = ["FARGATE"]
  network_mode       = "awsvpc"
  cpu                = "256"
  memory             = "512"
  execution_role_arn = aws_iam_role.ecs_task_execution.arn
  task_role_arn = aws_iam_role.ecs_task_execution.arn


  container_definitions = jsonencode([
    {
      name  = "config-service"
      image = var.config_service_image
      portMappings = [
        {
          containerPort = var.config_service_port
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = "/ecs/config-service"
          awslogs-region        = "ap-southeast-2"
          awslogs-stream-prefix = "ecs"
        }
      }
      environment = [
        { name = "AWS_REGION", value = "ap-southeast-2" },
        {
          name  = "SPRING_RABBITMQ_HOST"
          value = regex("amqps://(.*):5671", aws_mq_broker.rabbitmq.instances.0.endpoints[0])[0]
        },
        {
          name  = "SPRING_RABBITMQ_PORT"
          value = "5671"
        },
        {
          name  = "SPRING_RABBITMQ_USERNAME"
          value = "${var.rabbitmq_username}"
        },
        {
          name  = "SPRING_RABBITMQ_PASSWORD"
          value = "${var.rabbitmq_password != "" ? var.rabbitmq_password : random_password.rabbitmq.result}"
        },
        {
          name  = "SPRING_RABBITMQ_SSL_ENABLED"
          value = "true"
        }
      ]
    }
  ])
}


// ecs service for config service

resource "aws_ecs_service" "config" {
  name            = "config-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.config.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets = [aws_subnet.public_az1.id, aws_subnet.public_az2.id]
    assign_public_ip = true
    security_groups = [
      aws_security_group.ecs.id
    ]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.config.arn
    container_name   = "config-service"
    container_port   = var.config_service_port
  }

  depends_on = [aws_lb_target_group.config, aws_lb_listener.config]
}

// ecs task definition for catalog service
resource "aws_ecs_task_definition" "catalog" {
  family             = "catalog-service"
  requires_compatibilities = ["FARGATE"]
  network_mode       = "awsvpc"
  cpu                = "256"
  memory             = "512"
  execution_role_arn = aws_iam_role.ecs_task_execution.arn
  task_role_arn = aws_iam_role.ecs_task_execution.arn

  container_definitions = jsonencode([
    {
      name  = "catalog-service"
      image = var.catalog_service_image
      portMappings = [
        {
          containerPort = var.catalog_service_port
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = "/ecs/catalog-service"
          awslogs-region        = "ap-southeast-2"
          awslogs-stream-prefix = "ecs"
        }
      }
      environment = [
        {
          name  = "SPRING_CONFIG_IMPORT"
          value = "optional:configserver:http://${aws_lb.main.dns_name}:8888"
        },
        {
          name  = "SPRING_PROFILES_ACTIVE"
          value = "prod"
        },
        { name = "AWS_REGION", value = "ap-southeast-2" },
        {
          name  = "SPRING_RABBITMQ_HOST"
          value = regex("amqps://(.*):5671", aws_mq_broker.rabbitmq.instances.0.endpoints[0])[0]
        },
        {
          name  = "SPRING_RABBITMQ_PORT"
          value = "5671"
        },
        {
          name  = "SPRING_RABBITMQ_USERNAME"
          value = "${var.rabbitmq_username}"
        },
        {
          name  = "SPRING_RABBITMQ_PASSWORD"
          value = "${var.rabbitmq_password != "" ? var.rabbitmq_password : random_password.rabbitmq.result}"
        },
        {
          "name": "JAVA_TOOL_OPTIONS",
          "value": "-Djavax.net.debug=ssl,handshake"
        }
      ]
    }
  ])
}

// ecs task definition for demo-service

resource "aws_ecs_task_definition" "demoservice" {
  family             = "demo-service"
  requires_compatibilities = ["FARGATE"]
  network_mode       = "awsvpc"
  cpu                = "256"
  memory             = "512"
  execution_role_arn = aws_iam_role.ecs_task_execution.arn
  task_role_arn = aws_iam_role.ecs_task_execution.arn

  container_definitions = jsonencode([
    {
      name  = "demo-service"
      image = var.demo_service_image
      portMappings = [
        {
          containerPort = var.demo_service_port
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = "/ecs/demo-service"
          awslogs-region        = "ap-southeast-2"
          awslogs-stream-prefix = "ecs"
        }
      }
      environment = [
        {
          name  = "SPRING_CONFIG_IMPORT"
          value = "optional:configserver:http://${aws_lb.main.dns_name}:8888"
        },
        {
          name  = "SPRING_PROFILES_ACTIVE"
          value = "prod"
        },
        { name = "AWS_REGION", value = "ap-southeast-2" },
        {
          name  = "SPRING_RABBITMQ_HOST"
          value = regex("amqps://(.*):5671", aws_mq_broker.rabbitmq.instances.0.endpoints[0])[0]
        },
        {
          name  = "SPRING_RABBITMQ_PORT"
          value = "5671"
        },
        {
          name  = "SPRING_RABBITMQ_USERNAME"
          value = "${var.rabbitmq_username}"
        },
        {
          name  = "SPRING_RABBITMQ_PASSWORD"
          value = "${var.rabbitmq_password != "" ? var.rabbitmq_password : random_password.rabbitmq.result}"
        },
        {
          "name": "JAVA_TOOL_OPTIONS",
          "value": "-Djavax.net.debug=ssl,handshake"
        }
      ]
    }
  ])
}


// ecs service for catalog service

resource "aws_ecs_service" "catalog" {
  name            = "catalog-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.catalog.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets = [aws_subnet.public_az1.id, aws_subnet.public_az2.id]
    assign_public_ip = true
    security_groups = [
      aws_security_group.ecs.id
    ]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.catalog.arn
    container_name   = "catalog-service"
    container_port   = var.catalog_service_port
  }


  depends_on = [aws_lb_target_group.catalog,aws_ecs_service.config]
}


// ecs service for demo service

resource "aws_ecs_service" "demoservice" {
  name            = "demo-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.demoservice.arn
  desired_count   = 2
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = [aws_subnet.public_az1.id, aws_subnet.public_az2.id]
    assign_public_ip = true
    security_groups = [aws_security_group.ecs.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.demoservice.arn
    container_name   = "demo-service"
    container_port   = var.demo_service_port
  }

  depends_on = [aws_lb_target_group.demoservice, aws_lb_listener.demo]
}

// create the log groups
resource "aws_cloudwatch_log_group" "catalog_service" {
  name              = "/ecs/catalog-service"
  retention_in_days = 7 # Set log retention period (e.g., 7 days)

  tags = {
    Environment = "production" # Optional, specify tags as needed
    Service     = "catalog-service"
  }
}

resource "aws_cloudwatch_log_group" "config_service" {
  name              = "/ecs/config-service"
  retention_in_days = 7 # Set log retention period (e.g., 7 days)

  tags = {
    Environment = "production" # Optional, specify tags as needed
    Service     = "config-service"
  }
}

resource "aws_cloudwatch_log_group" "demo_service" {
  name              = "/ecs/demo-service"
  retention_in_days = 7 # Set log retention period (e.g., 7 days)

  tags = {
    Environment = "production" # Optional, specify tags as needed
    Service     = "demo-service"
  }
}

resource "aws_cloudwatch_log_group" "ssm_shell" {
  name              = "/ecs/ssm-shell"
  retention_in_days = 7 # Set log retention period (e.g., 7 days)

  tags = {
    Environment = "production" # Optional, specify tags as needed
    Service     = "ssm-shell"
  }
}


// busybox

resource "aws_ecs_task_definition" "busybox" {
  family                   = "busybox-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn

  container_definitions = jsonencode([
    {
      name  = "busybox"
      image = "busybox"
      command = ["sh", "-c", "while true; do sleep 3600; done"]
      essential = true
    }
  ])
}

/*resource "aws_ecs_service" "busybox_az1" {
  name            = "busybox-az1"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.busybox.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [aws_subnet.public_az1.id]
    assign_public_ip = true
    security_groups  = [aws_security_group.ecs.id]
  }
}

resource "aws_ecs_service" "busybox_az2" {
  name            = "busybox-az2"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.busybox.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [aws_subnet.public_az2.id]
    assign_public_ip = true
    security_groups  = [aws_security_group.ecs.id]
  }
}*/

// BusRefresh Scheduler Task Definition
resource "aws_ecs_task_definition" "busrefresh_scheduler" {
  family                   = "busrefresh-scheduler"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task_execution.arn

  container_definitions = jsonencode([
    {
      name      = "busrefresh-scheduler"
      image     = "curlimages/curl:latest"
      essential = true
      command   = ["sh", "-c", "curl -X POST http://${aws_lb.main.dns_name}:${var.config_service_port}/actuator/busrefresh"]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.busrefresh_scheduler.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])
}

// CloudWatch Log Group for BusRefresh Scheduler
resource "aws_cloudwatch_log_group" "busrefresh_scheduler" {
  name              = "/ecs/busrefresh-scheduler"
  retention_in_days = 7

  tags = {
    Environment = "production"
    Service     = "busrefresh-scheduler"
  }
}

// CloudWatch Event Rule for BusRefresh Scheduler
resource "aws_cloudwatch_event_rule" "busrefresh_scheduler" {
  name                = "busrefresh-scheduler-rule"
  description         = "Triggers the BusRefresh Scheduler task on a schedule"
  schedule_expression = var.busrefresh_schedule_expression
}

// CloudWatch Event Target for BusRefresh Scheduler
resource "aws_cloudwatch_event_target" "busrefresh_scheduler" {
  rule      = aws_cloudwatch_event_rule.busrefresh_scheduler.name
  target_id = "busrefresh-scheduler-target"
  arn       = aws_ecs_cluster.main.arn
  role_arn  = aws_iam_role.cloudwatch_events_role.arn

  ecs_target {
    task_count          = 1
    task_definition_arn = aws_ecs_task_definition.busrefresh_scheduler.arn
    launch_type         = "FARGATE"

    network_configuration {
      subnets          = [aws_subnet.public_az1.id, aws_subnet.public_az2.id]
      assign_public_ip = true
      security_groups  = [aws_security_group.ecs.id]
    }
  }
}

// IAM Role for CloudWatch Events to run ECS tasks
resource "aws_iam_role" "cloudwatch_events_role" {
  name = "cloudwatch-events-ecs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

// IAM Policy for CloudWatch Events to run ECS tasks
resource "aws_iam_role_policy" "cloudwatch_events_policy" {
  name = "cloudwatch-events-ecs-policy"
  role = aws_iam_role.cloudwatch_events_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecs:RunTask"
        ]
        Resource = [
          aws_ecs_task_definition.busrefresh_scheduler.arn
        ]
        Condition = {
          ArnLike = {
            "ecs:cluster" = aws_ecs_cluster.main.arn
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "iam:PassRole"
        ]
        Resource = [
          "*"
        ]
      }
    ]
  })
}

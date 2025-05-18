# Security group for RabbitMQ broker
resource "aws_security_group" "rabbitmq" {
  name        = "rabbitmq-sg"
  description = "Security group for RabbitMQ broker"
  vpc_id      = aws_vpc.springboot.id

  # AMQP with TLS port
  ingress {
    from_port   = 5671
    to_port     = 5671
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.springboot.cidr_block, aws_subnet.public_az1.cidr_block, aws_subnet.public_az2.cidr_block]
    description = "AMQP with TLS"
  }

  # Management console
  ingress {
    from_port   = 15672
    to_port     = 15672
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.springboot.cidr_block,aws_subnet.public_az1.cidr_block, aws_subnet.public_az2.cidr_block]
    description = "Management console"
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [aws_vpc.springboot.cidr_block]
  }

  tags = {
    Name = "rabbitmq-sg"
    App  = "springboot-app"
  }
}

# Random password for RabbitMQ if not provided
resource "random_password" "rabbitmq" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# AWS MQ RabbitMQ broker
resource "aws_mq_broker" "rabbitmq" {
  broker_name = "springboot-rabbitmq"

  engine_type        = "RabbitMQ"
  engine_version     = var.rabbitmq_engine_version
  host_instance_type = var.rabbitmq_instance_type

  # Single instance deployment
  deployment_mode = "SINGLE_INSTANCE"

  # # Make it publicly accessible
  # publicly_accessible = true

  # Deploy in public subnet
  subnet_ids = [aws_subnet.public_az1.id]

  # # Associate security group
  security_groups = [aws_security_group.rabbitmq.id]

  # Enable auto minor version upgrade (required for RabbitMQ 3.13)
  auto_minor_version_upgrade = true

  # User credentials
  user {
    username = var.rabbitmq_username
    password = var.rabbitmq_password != "" ? var.rabbitmq_password : random_password.rabbitmq.result
  }

  logs {
    general = true
  }

  tags = {
    Name = "springboot-rabbitmq"
    App  = "springboot-app"
  }
}

# Output the RabbitMQ connection details
output "rabbitmq_endpoints" {
  description = "RabbitMQ broker endpoints"
  value       = aws_mq_broker.rabbitmq.instances.0.endpoints
}

output "rabbitmq_console_url" {
  description = "RabbitMQ management console URL"
  value       = "https://${aws_mq_broker.rabbitmq.instances.0.console_url}"
}

output "rabbitmq_instance_endpoint" {
  description = "Use this RabbitMQ instance endpoint"
  value       = regex("amqps://(.*):5671", aws_mq_broker.rabbitmq.instances.0.endpoints[0])[0]
}

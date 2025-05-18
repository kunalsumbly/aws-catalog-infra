variable "aws_region" {
  description = "The AWS region to deploy resources into"
  type        = string
  default     = "ap-southeast-2" # Replace with your preferred default region if needed
}

variable vpc_cidr {
  default = "10.0.0.0/16"
  description = "vpc cidr"
  type = string
}

variable subnet_cidr {
  default = "10.0.1.0/24"
  description = "subnet cidr"
  type = string
}
variable aws_availability_zones {
  default = ["ap-southeast-2a"]
  description = "aws availability zones"
  type = list(string)
}

variable "catalog_service_image" {
  description = "ECR image for the catalog service"
  type        = string
}

variable "config_service_image" {
  description = "ECR image for the catalog service"
  type        = string
}

variable "catalog_service_port" {
  description = "Port for the catalog service"
  type        = number
}

variable "config_service_port" {
  description = "Port for the catalog service"
  type        = number
}

variable "rabbitmq_username" {
  description = "Username for RabbitMQ broker"
  type        = string
  default     = "admin"
  sensitive   = true
}

variable "rabbitmq_password" {
  description = "Password for RabbitMQ broker"
  type        = string
  sensitive   = true
}

variable "rabbitmq_instance_type" {
  description = "Instance type for RabbitMQ broker"
  type        = string
  default     = "mq.t3.micro"
}

variable "rabbitmq_engine_version" {
  description = "Engine version for RabbitMQ broker"
  type        = string
  default     = "3.13"
}

variable "aws_s3_bucket_name" {
  description = "Name of the S3 bucket"
  type        = string
  default     = "test-kunal-pii-logs"
}

output "vpc_id" {
  value = aws_vpc.springboot.id
  description = "The ID of the created VPC"
}

output "aws_spring_alb_arn" {
  value = aws_lb.main.dns_name
  description = "The ARN of the created ALB"
}

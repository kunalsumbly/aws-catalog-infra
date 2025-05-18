# Lambda function resources for PropertyRefresh

# Security group for Lambda function
resource "aws_security_group" "lambda_sg" {
  name        = "lambda-property-refresh-sg"
  description = "Security group for PropertyRefresh Lambda function"
  vpc_id      = aws_vpc.springboot.id

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "lambda-property-refresh-sg"
    App  = "springboot-app"
  }
}

# IAM role for Lambda function
resource "aws_iam_role" "lambda_role" {
  name = "property_refresh_lambda_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# CloudWatch Logs policy for Lambda
resource "aws_iam_policy" "lambda_logging" {
  name        = "lambda_logging_policy"
  description = "IAM policy for logging from Lambda"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# VPC access policy for Lambda
resource "aws_iam_policy" "lambda_vpc_access" {
  name        = "lambda_vpc_access_policy"
  description = "IAM policy for Lambda VPC access"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface"
        ]
        Resource = "*"
      }
    ]
  })
}

# Attach policies to Lambda role
resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_logging.arn
}

resource "aws_iam_role_policy_attachment" "lambda_vpc" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_vpc_access.arn
}

# CloudWatch log group for Lambda
resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/PropertyRefresh"
  retention_in_days = 7

  tags = {
    Environment = "production"
    Service     = "PropertyRefresh"
  }
}

# Create a zip file for the Lambda function code
resource "local_file" "lambda_function" {
  content = <<EOF
import json
import urllib.request
import os
import logging
import traceback

# Set up logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

def lambda_handler(event, context):
    # Get the config server URL from environment variable
    config_server_url = os.environ['CONFIG_SERVER_URL']

    logger.info(f"Received S3 event: {json.dumps(event)}")

    try:
        # Create a POST request to the config server
        req = urllib.request.Request(
            config_server_url,
            data=b'',  # Empty data for POST request
            method='POST'
        )

        # Add headers if needed
        req.add_header('Content-Type', 'application/json')

        # Send the request
        logger.info(f"Sending POST request to {config_server_url}")
        with urllib.request.urlopen(req) as response:
            response_body = response.read().decode('utf-8')
            logger.info(f"Response status: {response.status}")
            logger.info(f"Response body: {response_body}")

        return {
            'statusCode': 200,
            'body': json.dumps('Config server refresh triggered successfully')
        }
    except Exception as e:
        logger.error(f"Error triggering config server refresh: {str(e)}")
        traceback.print_exc()
        return {
            'statusCode': 500,
            'body': json.dumps(f'Error: {str(e)}')
        }
EOF
  filename = "${path.module}/lambda_function.py"
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = local_file.lambda_function.filename
  output_path = "${path.module}/lambda_function_payload.zip"
}

# Lambda function
resource "aws_lambda_function" "property_refresh" {
  function_name = "PropertyRefresh"
  role          = aws_iam_role.lambda_role.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.9"
  timeout       = 900

  # # Deploy in the same subnet as config service
  # vpc_config {
  #   subnet_ids         = [aws_subnet.public_az1.id, aws_subnet.public_az2.id]
  #   security_group_ids = [aws_security_group.lambda_sg.id]
  # }

  # Environment variables
  environment {
    variables = {
      CONFIG_SERVER_URL = "http://${aws_lb.main.dns_name}:8888/actuator/busrefresh"
    }
  }

  # Use the zip file created by archive_file
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  tags = {
    Name = "PropertyRefresh"
    App  = "springboot-app"
  }

  depends_on = [aws_cloudwatch_log_group.lambda_logs]
}

# S3 bucket notification configuration
resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = var.aws_s3_bucket_name

  lambda_function {
    lambda_function_arn = aws_lambda_function.property_refresh.arn
    events              = ["s3:ObjectCreated:Put"]
    filter_suffix       = ".properties"  # Trigger for property files
  }

  lambda_function {
    lambda_function_arn = aws_lambda_function.property_refresh.arn
    events              = ["s3:ObjectCreated:Put"]
    filter_suffix       = ".yml"  # Trigger for YAML files
  }
}

# Lambda permission for S3
resource "aws_lambda_permission" "allow_bucket" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.property_refresh.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = "arn:aws:s3:::${var.aws_s3_bucket_name}"
}

# Output the Lambda function ARN
output "property_refresh_lambda_arn" {
  description = "ARN of the PropertyRefresh Lambda function"
  value       = aws_lambda_function.property_refresh.arn
}

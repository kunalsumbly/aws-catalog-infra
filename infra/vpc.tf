
data "aws_availability_zones" "available" {}

# VPC
resource "aws_vpc" "springboot" {
  cidr_block = "10.0.0.0/16"

  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "springboot-app-vpc"
    App  = "springboot-app"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.springboot.id

  tags = {
    Name = "springboot-app-igw"
    App  = "springboot-app"
  }
}

# Public Subnet 1 (AZ 1)
resource "aws_subnet" "public_az1" {
  vpc_id                  = aws_vpc.springboot.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet-az1"
    App  = "springboot-app"
  }
}

# Public Subnet 2 (AZ 2)
resource "aws_subnet" "public_az2" {
  vpc_id                  = aws_vpc.springboot.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet-az2"
    App  = "springboot-app"
  }
}

# Route Table (shared by both public subnets)
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.springboot.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "springboot-app-public-rt"
    App  = "springboot-app"
  }
}

# Route Table Associations
resource "aws_route_table_association" "az1" {
  subnet_id      = aws_subnet.public_az1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "az2" {
  subnet_id      = aws_subnet.public_az2.id
  route_table_id = aws_route_table.public.id
}

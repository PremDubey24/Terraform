provider "aws" {
   region = "eu-north-1" # Change to your desired region
}

# Create VPC
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"  # Adjust CIDR block as needed
  enable_dns_support = true
  enable_dns_hostnames = true
  tags = {
    Name = "VPC"
  }
}

# Create public subnet
resource "aws_subnet" "public" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"  # Adjust CIDR block as needed
  availability_zone = "eu-north-1a"   # Change to your desired AZ
  map_public_ip_on_launch = true
  tags = {
    Name = "Public Subnet"
  }
}

# Create private subnet
resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"  # Adjust CIDR block as needed
  availability_zone = "eu-north-1a"   # Change to your desired AZ
  tags = {
    Name = "Private Subnet"
  }
}

# Create internet gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "IGW"
  }
}

# Attach internet gateway to VPC
resource "aws_internet_gateway_attachment" "gw_attachment" {
  vpc_id              = aws_vpc.main.id
  internet_gateway_id = aws_internet_gateway.gw.id
}

# Create route table for public subnet
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
  tags = {
    Name = "Public_RT"
  }
}

# Create route table for private subnet
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
  tags = {
    Name = "Private_RT"
  }
}

# Associate public subnet with public route table
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Allocate Elastic IP for NAT Gateway
resource "aws_eip" "nat" {
  vpc = true
}

# Create NAT Gateway
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id
}

# Add route to private route table for NAT Gateway
resource "aws_route" "private" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat.id
}

# Create security group for public subnet
resource "aws_security_group" "public" {
  vpc_id = aws_vpc.main.id

  // Add rules as needed for inbound and outbound traffic
}

# Create security group for private subnet
resource "aws_security_group" "private" {
  vpc_id = aws_vpc.main.id

  // Add rules as needed for inbound and outbound traffic
}

# You can create instances or other resources within the subnets here

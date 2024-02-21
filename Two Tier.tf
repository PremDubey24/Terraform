provider "aws" {
  region = "eu-north-1" # Change to your desired region
}

# Create VPC
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support  = true
  enable_dns_hostnames = true
  tags = {
    Name = "VPC"
  }
}

resource "aws_security_group" "vpc_sg" {

  vpc_id = aws_vpc.main.id

  # Ingress rules (inbound traffic)
  ingress {
    description = "Allow SSH traffic from specific IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  // Restrict this to specific IPs if possible
  }

  ingress {
    description = "Allow SSH traffic from specific IP"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  // Restrict this to specific IPs if possible
  }

  ingress {
    description = "Allow SSH traffic from specific IP"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  // Restrict this to specific IPs if possible
  }

  ingress {
    description = "Allow HTTP traffic from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Egress rules (outbound traffic)
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


# Create public subnet
resource "aws_subnet" "public" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "eu-north-1a"
  map_public_ip_on_launch = true
  tags = {
    Name = "Public Subnet"
  }
}

# Create private subnet
resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "eu-north-1a"
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
  connectivity_type = "public"
  subnet_id     = aws_subnet.public.id
  tags = {
    Name = "NAT"
  }
}

# Create route table for private subnet
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  tags = {
Name = "Private_RT"
}
}

# Add route to private route table for NAT Gateway
resource "aws_route" "private" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat.id
}

# Associate private subnet with private route table
resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}

# Define IAM policy for full RDS access
resource "aws_iam_policy" "rds_full_access_policy" {
  name        = "RDSFullAccessPolicy"
  description = "Provides full access to RDS resources"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect   = "Allow",
      Action   = "rds:*",
      Resource = "*",
    }]
  })
}

# Create IAM role
resource "aws_iam_role" "ec2_rds_role" {
  name               = "EC2RDSRole"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = {
        Service = "ec2.amazonaws.com"
      },
      Action    = "sts:AssumeRole"
    }]
  })
}

# Attach policy to IAM role
resource "aws_iam_role_policy_attachment" "rds_full_access_attachment" {
  role       = aws_iam_role.ec2_rds_role.name
  policy_arn = aws_iam_policy.rds_full_access_policy.arn
}

# Create an instance for Public Subnet (Tomcat)
resource "aws_instance" "public_instance" {
  ami           = "ami-0014ce3e52359afbd" 
  instance_type = "t3.micro"
  subnet_id     = aws_subnet.public.id
  key_name      = "Ubuntu-1"
  security_groups = [aws_security_group.vpc_sg.id]
  user_data = <<-EOF
#!/bin/bash
sudo -i
apt update
apt install unzip -y
apt install -y openjdk-17-jdk
wget https://dlcdn.apache.org/tomcat/tomcat-8/v8.5.98/bin/apache-tomcat-8.5.98.zip
unzip apache-tomcat-8.5.98.zip -d /opt
chmod 777 /opt/apache-tomcat-8.5.98/bin/catalina.sh
wget https://s3-us-west-2.amazonaws.com/studentapi-cit/mysql-connector.jar
cp mysql-connector.jar /opt/apache-tomcat-8.5.98/lib/
wget https://s3-us-west-2.amazonaws.com/studentapi-cit/student.war
cp student.war /opt/apache-tomcat-8.5.98/webapps/
EOF

  tags = {
    env = "tomcat"
    Name = "TOMCAT"
  }
}

# Create an instance for Private Subnet (Mariadb)
resource "aws_instance" "private_instance" {
  ami           = "ami-0014ce3e52359afbd" 
  instance_type = "t3.micro"
  iam_instance_profile = aws_iam_role.ec2_rds_role.name # Associate IAM role with EC2 instance
  subnet_id     = aws_subnet.private.id
  key_name      = "Ubuntu-1"
  security_groups = [aws_security_group.vpc_sg.id]
  user_data = <<-EOF
  #!/bin/bash
  sudo -i
  apt update
  apt install mariadb-server-10.6 -y
  systemctl start mariadb
  systemctl enable mariadb
  apt install -y openjdk-17-jdk
  EOF

  tags = {
    env = "Mariadb"
    Name = "DB-Server"
  }
}

# Create an RDS instance
resource "aws_db_instance" "backend-rds" {
  identifier                = "mariadb-db"
  allocated_storage         = 20
  storage_type              = "gp2"
  engine                    = "mariadb"
  engine_version            = "10.5.12"
  instance_class            = "db.t2.micro"
  username                  = "admin"
  password                  = "admin123"
  publicly_accessible       = false
  skip_final_snapshot       = true
  backup_retention_period   = 7
  multi_az                  = false
  monitoring_interval       = 0
  allow_major_version_upgrade = false
  vpc_security_group_ids    = [aws_security_group.vpc_sg.id]
}
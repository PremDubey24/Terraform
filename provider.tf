provider "aws" {
    region = "us-east-1"
    
}

resource "aws_instance" "Terraform" {
  ami = "ami-08e5424edfe926b43"
  instance_type = "t2.micro"
  key_name = "TFKEY.pem"
  tags = { 
    env = "dev"
    name = "TF-instance"
  }
  vpc_security_group_ids = ["sg-08f94a2c1d9433db6"]
  
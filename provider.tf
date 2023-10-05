provider "aws" {
    region = "us-east-1"
    
}

resource "aws_instance" "Terraform" {
  ami = "ami-08e5424edfe926b43"
  instance_type = "t2.micro"
  key_name = "TFKEY"
  vpc_security_group_ids = ["sg-0e411a3455293c130"]
  
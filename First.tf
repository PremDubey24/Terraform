provider "aws" {
   region = "eu-north-1"
}

resource "aws_instance" "my-instance" {
    ami = "ami-0014ce3e52359afbd"
    instance_type = "t3.micro"
    key_name = "Ubuntu-1"
    tags = {
      env = "dev"
      Name = "TF-Instance"
    }
    vpc_security_group_ids = ["sg-0b86b0265bfc094fc"]
}

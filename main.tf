# Configure the AWS Provider
provider "aws" {
  region = "ca-central-1"
}

# create default vpc if one does not exit
resource "aws_default_vpc" "default_vpc" {
}

  # Create Web Security Group
resource "aws_security_group" "web-sg" {
  name        = "docker-Web-SG"
  description = "Allow ssh and http inbound traffic"
  vpc_id      = aws_default_vpc.default_vpc.id

 dynamic "ingress" {
    for_each = [22, 80, 443]  # Add your desired ingress port numbers here
    content {
      description = "ingress port ${ingress.value}"
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "docker-Web-SG"
  }
}

  
# Generates a secure private k ey and encodes it as PEM
resource "tls_private_key" "ec2_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}
# Create the Key Pair
resource "aws_key_pair" "ec2_key" {
  key_name   = "privatekeypair"  
  public_key = tls_private_key.ec2_key.public_key_openssh
}
# Save file
resource "local_file" "ssh_key" {
  filename = "keypair.pem"
  content  = tls_private_key.ec2_key.private_key_pem
}

#data for amazon linux

data "aws_ami" "amazon-2" {
    most_recent = true
  
    filter {
      name = "name"
      values = ["amzn2-ami-hvm-*-x86_64-ebs"]
    }
    owners = ["amazon"]
  }
 
#create ec2 instances 

resource "aws_instance" "DockerInstance" {
  ami                    = data.aws_ami.amazon-2.id
  instance_type          = "t2.micro"
  vpc_security_group_ids = ["${ aws_security_group.web-sg.id }"]
  key_name               = aws_key_pair.ec2_key.key_name
  user_data              = file("install.sh")
 
  tags = {
    Name = "docker instance"
  }
}


output "ssh-command" {
  value = join ("", ["ssh -i keypair.pem ec2-user@", aws_instance.DockerInstance.public_dns ])
}
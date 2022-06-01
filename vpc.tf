provider "aws" {

}
###################################################################
######                                VPC                     #####
###################################################################
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name  = "alexk_vpc"
    Owner = "alexk"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name  = "alexk_igw"
    Owner = "alexk"
  }
}

resource "aws_subnet" "public_A" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.11.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = "true" # auto-assign public IP

  tags = {
    Name  = "alexk_public_subnet_A"
    Owner = "alexk"
  }
}

resource "aws_subnet" "public_B" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.21.0/24"
  availability_zone       = "us-east-1b" # auto-assign public IP
  map_public_ip_on_launch = "true"

  tags = {
    Name  = "alexk_public_subnet_B"
    Owner = "alexk"
  }
}

resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name  = "alexk_public_route_table"
    Owner = "alexk"
  }
}


resource "aws_route_table_association" "public_A" {
  subnet_id      = aws_subnet.public_A.id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_route_table_association" "public_B" {
  subnet_id      = aws_subnet.public_B.id
  route_table_id = aws_route_table.public_route_table.id
}


resource "aws_subnet" "private_A" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.12.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name  = "alexk_private_subnet_A"
    Owner = "alexk"
  }
}

resource "aws_subnet" "private_B" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.22.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name  = "alexk_private_subnet_B"
    Owner = "alexk"
  }
}


resource "aws_eip" "eip_A" {
  tags = {
    Name  = "alexk_EIP_A"
    Owner = "alexk"
  }
  # EIP may require IGW  to exist prior to association
  depends_on = [aws_internet_gateway.gw]
}

resource "aws_eip" "eip_B" {
  tags = {
    Name  = "alexk_EIP_B"
    Owner = "alexk"
  }
  # EIP may require IGW  to exist prior to association
  depends_on = [aws_internet_gateway.gw]
}

resource "aws_nat_gateway" "nat_A" {
  allocation_id = aws_eip.eip_A.id
  subnet_id     = aws_subnet.public_A.id

  tags = {
    Name  = "alexk_NAT_GW_A"
    Owner = "alexk"
  }
}

resource "aws_nat_gateway" "nat_B" {
  allocation_id = aws_eip.eip_B.id
  subnet_id     = aws_subnet.public_B.id

  tags = {
    Name  = "alexk_NAT_GW_B"
    Owner = "alexk"
  }
}

resource "aws_route_table" "private_route_table_A" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.nat_A.id
  }

  tags = {
    Name  = "alexk_private_route_table_A"
    Owner = "alexk"
  }
}

resource "aws_route_table" "private_route_table_B" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.nat_B.id
  }

  tags = {
    Name  = "alexk_private_route_table_B"
    Owner = "alexk"
  }
}

resource "aws_route_table_association" "private_A" {
  subnet_id      = aws_subnet.private_A.id
  route_table_id = aws_route_table.private_route_table_A.id
}

resource "aws_route_table_association" "private_B" {
  subnet_id      = aws_subnet.private_B.id
  route_table_id = aws_route_table.private_route_table_B.id
}


################################################################################################################
#####                                  BASTION                                                          ########
################################################################################################################

resource "aws_s3_bucket" "bucket_for_ssh_key" {
  bucket = "alexk-test-for-keys"

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }
}

resource "aws_s3_bucket_public_access_block" "bucket_for_ssh_key" {
  bucket = aws_s3_bucket.bucket_for_ssh_key.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

output "bucket" {
  value = aws_s3_bucket.bucket_for_ssh_key.id
}

resource "tls_private_key" "pkey" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "kpair" {
  key_name   = "bastion"
  public_key = tls_private_key.pkey.public_key_openssh

  provisioner "local-exec" {
    command = <<EOT
echo '${tls_private_key.pkey.private_key_pem}' > ./{privatekey_name}
echo '${tls_private_key.pkey.public_key_openssh}' > ./{publickey_name}
aws s3api put-object --bucket '${aws_s3_bucket.bucket_for_ssh_key.id}' --key {privatekey_name} --body {privatekey_name}
aws s3api put-object --bucket '${aws_s3_bucket.bucket_for_ssh_key.id}' --key {publickey_name} --body {publickey_name}
rm ./{publickey_name} ./{privatekey_name}
EOT     
  }
}

data "aws_ami" "ec2_image" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-kernel-5.10-hvm*"]
  }

}

data "http" "ip" { # to get know my IP 
  url = "https://ifconfig.me"
}

output "ip" {
  value = data.http.ip.body
}

resource "aws_security_group" "allow_ssh_bastion" {
  name        = "allow_ssh_bastion"
  description = "Allows SSH to Bastion host"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH to Bastion"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${chomp(data.http.ip.body)}/32"] # My IP (chomp removes newline characters at the end of a string)
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_ssh_bastion"
  }
}

resource "aws_launch_template" "alexk_bastion_lt" {
  name = "alexk_bastion_lt"

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size = 8
    }
  }

  instance_type          = "t2.micro"
  image_id               = data.aws_ami.ec2_image.id
  vpc_security_group_ids = [aws_security_group.allow_ssh_bastion.id]
  key_name               = aws_key_pair.kpair.id
}


resource "aws_autoscaling_group" "bastion_asg" {
  name                = "alexk_asg"
  vpc_zone_identifier = [aws_subnet.public_A.id, aws_subnet.public_B.id]
  desired_capacity    = 1
  max_size            = 1
  min_size            = 0

  launch_template {
    id      = aws_launch_template.alexk_bastion_lt.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "alexk-bastion"
    propagate_at_launch = true
  }

  #target_group_arns = [aws_lb_target_group.bastion_tg.arn]
}

################################################################################################################
#####                                      NLB                                                          ########
################################################################################################################

resource "aws_lb_target_group" "bastion_tg" {
  name     = "alexk-bastion-tf-nlb-tg"
  port     = 80
  protocol = "TCP"
  vpc_id   = aws_vpc.main.id
}

resource "aws_lb" "bastion_nlb" {
  name               = "alexk-bastion-nlb-tf"
  internal           = false
  load_balancer_type = "network"
  subnets            = [aws_subnet.public_A.id, aws_subnet.public_B.id]
}

resource "aws_autoscaling_attachment" "asg_attachment_bar" {
  autoscaling_group_name = aws_autoscaling_group.bastion_asg.id
  lb_target_group_arn    = aws_lb_target_group.bastion_tg.arn
}





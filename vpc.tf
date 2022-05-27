provider "aws" {

}

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

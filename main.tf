# VPCs
resource "aws_vpc" "vpcs" {
  for_each             = var.vpcs
  cidr_block           = each.value.cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags                 = {
    Name               = "${each.key}-vpc"
  }
}

# Subnets
resource "aws_subnet" "public_subnets" {
  vpc_id                  = aws_vpc.vpcs["vpc-A"].id
  cidr_block              = "10.1.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags                    = {
    Name                  = "public-subnet"
  }
}

resource "aws_subnet" "private_subnets" {
  for_each          = var.vpcs
  vpc_id            = aws_vpc.vpcs[each.key].id
  cidr_block        = each.value.subnet_private
  availability_zone = each.value.az

  tags              = {
    Name            = "${each.key}-private-subnet"
  }
}

# # Internet Gateways
resource "aws_internet_gateway" "igws" {
  vpc_id   = aws_vpc.vpcs["vpc-A"].id

  tags     = {
    Name   = "vpc-A-igw"
  }
}

# TGW
resource "aws_ec2_transit_gateway" "main" {
  description                     = "Main Transit Gateway"
  amazon_side_asn                 = 64512
  auto_accept_shared_attachments  = "enable"
  default_route_table_association = "disable"
  default_route_table_propagation = "disable"
  vpn_ecmp_support                = "enable"
  dns_support                     = "enable"
  tags                            = {
    Name                          = "main-tgw"
  }
}

resource "aws_ec2_transit_gateway_route_table" "main" {
  for_each = var.vpcs

  transit_gateway_id = aws_ec2_transit_gateway.main.id

  tags = {
    Name = "${each.key}-tgw-rt"
  }
}

# # Public Route Tables
resource "aws_route_table" "public_rts" {
  vpc_id = aws_vpc.vpcs["vpc-A"].id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igws.id
  }
  route {
    cidr_block = "10.2.0.0/16"
    transit_gateway_id = aws_ec2_transit_gateway.main.id
  }

  tags = {
    Name = "public-rt"
  }
}

# private rt
resource "aws_route_table" "private_route_table-A" {
  vpc_id = aws_vpc.vpcs["vpc-A"].id

  route {
    cidr_block = "10.2.0.0/16"
    transit_gateway_id = aws_ec2_transit_gateway.main.id
  }

  tags = {
    Name = "private-rt-A"
  }
}

resource "aws_route_table" "private_route_table-B" {
  vpc_id = aws_vpc.vpcs["vpc-B"].id

  route {
    cidr_block = "10.1.0.0/16"
    transit_gateway_id = aws_ec2_transit_gateway.main.id
  }

  tags = {
    Name = "private-rt-B"
  }
}

# Associate Public Subnets
resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public_subnets.id
  route_table_id = aws_route_table.public_rts.id
}

# Associate Private Subnets
resource "aws_route_table_association" "private_assoc" {
  subnet_id      = aws_subnet.private_subnets["vpc-A"].id
  route_table_id = aws_route_table.private_route_table-A.id
}

resource "aws_route_table_association" "private_assoc-B" {
  subnet_id      = aws_subnet.private_subnets["vpc-B"].id
  route_table_id = aws_route_table.private_route_table-B.id
}

resource "aws_ec2_transit_gateway_vpc_attachment" "attachments" {
  for_each           = var.vpcs
  transit_gateway_id = aws_ec2_transit_gateway.main.id
  vpc_id             = aws_vpc.vpcs[each.key].id
  subnet_ids         = [aws_subnet.private_subnets[each.key].id]

  tags               = {
    Name             = "${each.key}-tgw-attachment"
  }
}

# Associate attachments with TGW route table
resource "aws_ec2_transit_gateway_route_table_association" "assoc" {
  for_each                       = aws_ec2_transit_gateway_vpc_attachment.attachments
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.main[each.key].id
  transit_gateway_attachment_id  = each.value.id
}

resource "aws_ec2_transit_gateway_route_table_propagation" "tgw_rt_prop-A" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.attachments["vpc-B"].id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.main["vpc-A"].id
}

resource "aws_ec2_transit_gateway_route_table_propagation" "tgw_rt_prop-B" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.attachments["vpc-A"].id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.main["vpc-B"].id
}

# Security Groups
resource "aws_security_group" "sg" {
  for_each = var.vpcs
  name     = "${each.key}-sg"
  vpc_id   = aws_vpc.vpcs[each.key].id

  ingress {
    description = "Allow SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.vpcs.vpc-A.subnet_public]
  }

  ingress {
    description = "Allow ICMP (ping)"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags          = {
    Name        = "${each.key}-sg"
  }
}

# EC2 instances (one per VPC in private subnet)
resource "aws_instance" "ec2_instances" {
  for_each      = var.vpcs
  ami           = "ami-0bdd88bd06d16ba03" 
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.private_subnets[each.key].id
  key_name      = "amora"  
  vpc_security_group_ids = [aws_security_group.sg[each.key].id]
  tags          = {
    Name        = "${each.key}-ec2"
  }
}

resource "aws_security_group" "bastion_sg" {
  vpc_id = aws_vpc.vpcs["vpc-A"].id
  name   = "bastion-sg"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "bastion-sg"
  }
}


resource "aws_instance" "bastion" {
  ami                    = "ami-080c353f4798a202f" 
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.public_subnets.id
  key_name               = "amora1" 
  associate_public_ip_address = true
  vpc_security_group_ids = [aws_security_group.bastion_sg.id]

  tags = {
    Name = "bastion-host"
  }
}


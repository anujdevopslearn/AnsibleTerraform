
provider "aws" {
        region = var.aws_region
}

variable "aws_region" {
        default = "us-east-1"
}

variable "vpc_cidr" {
        default = "10.20.0.0/16"
}

variable "subnets_cidr" {
        default = "10.20.1.0/24"
}

variable "azs" {
        default = "us-east-1a"
}



# VPC
resource "aws_vpc" "terra_vpc" {
  cidr_block       = var.vpc_cidr
  tags = {
    Name = "TerraVPC"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "terra_igw" {
  vpc_id = aws_vpc.terra_vpc.id
  tags = {
    Name = "main"
  }
}

# Subnets : public
resource "aws_subnet" "public" {
  vpc_id = aws_vpc.terra_vpc.id
  cidr_block = var.subnets_cidr
  availability_zone = var.azs
  map_public_ip_on_launch = true
  tags = {
    Name = "Subnet"
  }
}

# Route table: attach Internet Gateway 
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.terra_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.terra_igw.id
  }
  tags = {
    Name = "publicRouteTable"
  }
}

# Route table association with public subnets
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public_rt.id
}


resource "aws_security_group" "dev_vm_security_group" {
  name = "sg_dev_vm"
  description = "Dev VM security group."
  vpc_id = aws_vpc.terra_vpc.id
}

resource "aws_security_group_rule" "ssh_ingress_access" {
  type = "ingress"
  from_port = 22
  to_port = 22
  protocol = "tcp"
  cidr_blocks = [ "0.0.0.0/0" ] 
  security_group_id = "${aws_security_group.dev_vm_security_group.id}"
}

resource "aws_security_group_rule" "egress_access" {
  type = "egress"
  from_port = 0
  to_port = 65535
  protocol = "tcp"
  cidr_blocks = [ "0.0.0.0/0" ]
  security_group_id = "${aws_security_group.dev_vm_security_group.id}"
}

data "aws_ami" "latest-ubuntu" {
most_recent = true

  filter {
      name   = "name"
      values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-20240701.1"]
  }

  filter {
      name   = "virtualization-type"
      values = ["hvm"]
  }
}

resource "aws_instance" "dev_instance" {
  instance_type = "t2.micro"
  vpc_security_group_ids = [ "${aws_security_group.dev_vm_security_group.id}" ]
  associate_public_ip_address = true
  tags = {
    Name = "dev-instance"
  }
  ami = "${data.aws_ami.latest-ubuntu.id}"
  availability_zone = "${var.azs}"
  subnet_id = "${aws_subnet.public.id}"
}

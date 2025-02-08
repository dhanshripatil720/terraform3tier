terraform {

  required_version = "~> 1.1"

  required_providers {

    aws = {

      version = "~>3.1"

    }

  }

}

provider "aws" {

  region     = var.my_region
  access_key = var.access_key
  secret_key = var.secret_key

}

resource "aws_vpc" "customvpc" {

  cidr_block       = "10.0.0.0/16"

  tags = {

    Name = "myvpc"

  }

}

resource "aws_internet_gateway" "myigw" {

  vpc_id = aws_vpc.customvpc.id

  tags = {

    Name = "myigw"

  }

}

resource "aws_subnet" "web-subnet" {

  vpc_id     = aws_vpc.customvpc.id

  cidr_block = "10.0.0.0/20"

  availability_zone = "us-east-1a"

  tags = {

    Name = "websubnet"

  }

}

resource "aws_subnet" "app-subnet" {

  vpc_id     = aws_vpc.customvpc.id

  cidr_block = "10.0.16.0/20"

  availability_zone = "us-east-1b"

  tags = {

    Name = "appsubnet"

  }

}

resource "aws_subnet" "db-subnet" {

  vpc_id     = aws_vpc.customvpc.id

  cidr_block = "10.0.32.0/24"

  availability_zone = "us-east-1c"

  tags = {

    Name = "dbsubnet "

  }

}

resource "aws_route_table" "public-rt" {

  vpc_id = aws_vpc.customvpc.id

 

  route {

    cidr_block = "0.0.0.0/0"

    gateway_id = aws_internet_gateway.myigw.id

  }

  tags = {

    Name = "public-RT"

  }

}

resource "aws_route_table" "pvt-rt" {

  vpc_id = aws_vpc.customvpc.id

 

  tags = {

    Name = "pvt-RT"

  }

}

resource "aws_route_table_association" "web-association" {

  subnet_id      = aws_subnet.web-subnet.id

  route_table_id = aws_route_table.public-rt.id

}

resource "aws_route_table_association" "app-association" {

  subnet_id      = aws_subnet.app-subnet.id

  route_table_id = aws_route_table.pvt-rt.id

}

resource "aws_route_table_association" "db-association" {

  subnet_id      = aws_subnet.db-subnet.id

  route_table_id = aws_route_table.pvt-rt.id

}

resource "aws_security_group" "my-websg" {

  name   = "my-websg"

  vpc_id = aws_vpc.customvpc.id

  egress {

    from_port = 0

    to_port   = 0

    protocol  = "-1"

    cidr_blocks = ["0.0.0.0/0"]

  }

  ingress {

    cidr_blocks = ["0.0.0.0/0"]

    from_port   = 22

    protocol    = "tcp"

    to_port     = 22

  }

  ingress {

    cidr_blocks = ["0.0.0.0/0"]

    from_port   = 80

    protocol    = "tcp"

    to_port     = 80

  }

}

resource "aws_security_group" "my-appsg" {

  name   = "my-appsg"

  vpc_id = aws_vpc.customvpc.id

  egress {

    from_port = 0

    to_port   = 0

    protocol  = "-1"

    cidr_blocks = ["0.0.0.0/0"]

  }

  ingress {

    cidr_blocks = ["10.0.0.0/16"]

    from_port   = 22

    protocol    = "tcp"

    to_port     = 22

  }

  ingress {

    cidr_blocks = ["10.0.0.0/20"]

    from_port   = 9000

    protocol    = "tcp"

    to_port     = 9000

  }

}

resource "aws_security_group" "my-dbsg" {

  name   = "my-dbsg"

  vpc_id = aws_vpc.customvpc.id

  egress {

    from_port = 0

    to_port   = 0

    protocol  = "-1"

    cidr_blocks = ["0.0.0.0/0"]

  }

  ingress {

    cidr_blocks = ["10.0.0.0/16"]

    from_port   = 22

    protocol    = "tcp"

    to_port     = 22

  }

  ingress {

    cidr_blocks = ["10.0.16.0/20"]

    from_port   = 3306

    protocol    = "tcp"

    to_port     = 3306

  }

}

resource "aws_instance" "web" {

  ami                    = var.my_ami

  instance_type          = var.ins_type

  vpc_security_group_ids = [aws_security_group.my-websg.id]

  subnet_id = aws_subnet.web-subnet.id

  associate_public_ip_address = true

  tags = {

    Name = "webserver"

  }

  key_name = "mytf-key1"

}

resource "aws_instance" "app" {

  subnet_id = aws_subnet.app-subnet.id

  ami                    = var.my_ami

  instance_type          = var.ins_type

  vpc_security_group_ids = [aws_security_group.my-appsg.id]

  tags = {

    Name = "appserver"

 }

  key_name = "mytf-key1"

}

resource "aws_db_instance" "my-rds" {

  allocated_storage    = 10

  engine               = "mysql"

  engine_version       = "8.0"

  instance_class       = "db.t3.micro"

  username             = "admin"

  password             = "Pass1234"

  vpc_security_group_ids = [aws_security_group.my-dbsg.id]

  db_subnet_group_name = aws_db_subnet_group.my-subnet-grp.name

  skip_final_snapshot  = true

}

resource "aws_db_subnet_group" "my-subnet-grp" {

  name       = "my-sub-grp"

  subnet_ids = [aws_subnet.app-subnet.id, aws_subnet.db-subnet.id]

 

  tags = {

    Name = "My DB subnet group"

  }

}

resource "aws_key_pair" "tf-key-pair" {

  key_name   = "mytf-key1"

  public_key = tls_private_key.rsa.public_key_openssh

}

resource "tls_private_key" "rsa" {

  algorithm = "RSA"

  rsa_bits  = 4096

}

resource "local_file" "tf-key" {

  content  = tls_private_key.rsa.private_key_pem

  filename = "mytf-key1"
}

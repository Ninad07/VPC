#AWS
provider "aws" {
  region = "ap-south-1"
}

#VARIABLES
variable "public_subnet_cidr" {
  description = "CIDR for public subnet"
  default = "10.0.0.0/24"
}

variable "private_subnet_cidr" {
  description = "CIDR for private subnet"
  default = "10.0.1.0/24"
}

variable "vpc_cidr" {
  description = "CIDR for the whole VPC"
  default = "192.10.0.0/16"
}


#MAIN VPC
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr
  enable_dns_hostnames = true
  tags = {
    Name = "MyVPC"
  }
}

#PUBLIC SUBNET
resource "aws_subnet" "subnet_public" {
  vpc_id = aws_vpc.main.id
  cidr_block = "192.10.0.0/24"
  map_public_ip_on_launch = true
  availability_zone = "ap-south-1a"

  tags = {
    Name = "Public Subnet"
  }
}

resource "aws_route_table" "public_subnet_route" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.rt_gateway.id
  }

  tags = {
    Name = "public_ig"
  }
}

resource "aws_route_table_association" "public_route" {
  subnet_id = aws_subnet.subnet_public.id
  route_table_id = aws_route_table.public_subnet_route.id
}


#PRIVATE SUBNET
resource "aws_subnet" "subnet_private" {
  vpc_id = aws_vpc.main.id
  availability_zone = "ap-south-1b"
  cidr_block = "192.10.1.0/24"
  map_public_ip_on_launch = false

  tags = {
   Name = "Private Subnet"
  }
}


#WORDPRESS SERVER SECURITY GROUP
resource "aws_security_group" "wordpress_sec" {
  name = "wordpress-sec"
  description = "Allow all traffic inbound"

  ingress {
    description = "SSH"
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
 
  ingress {
    description = "ICMP"
    from_port = -1
    to_port = -1
    protocol = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  #MYSQL
  egress { 
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  vpc_id = aws_vpc.main.id
}



#MYSQL SERVER SECURITY GROUP 
resource "aws_security_group" "mysql_sec" {
  name = "mysql-sec"
  description = "Allow only Apache Webserver traffic inbound"
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "MySQL DB"
  }

  ingress {
    description = "MySQL Server"
    from_port = 3306
    to_port = 3306
    protocol = "tcp"
    security_groups = [aws_security_group.wordpress_sec.id]
  }

  ingress {
     description = "PING"
    from_port = -1
    to_port = -1
    protocol = "icmp"
    security_groups = [aws_security_group.wordpress_sec.id]
  }

  ingress {
     description = "SSH"
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  egress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
    
  egress {
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#INTERNET GATEWAY
resource "aws_internet_gateway" "rt_gateway" {
  vpc_id = aws_vpc.main.id
}


resource "aws_eip" "dbeip" {
  instance = aws_instance.mariadb.id
  vpc = true

  depends_on = [aws_internet_gateway.rt_gateway]
}

 
#MYSQL INSTANCE
resource "aws_instance" "mariadb" {
  ami = "ami-07db174826ca4a3c9"
  availability_zone = "ap-south-1b"
  instance_type = "t2.micro"
  key_name = "mykey"
  vpc_security_group_ids = [aws_security_group.mysql_sec.id]
  subnet_id = aws_subnet.subnet_private.id
  associate_public_ip_address = false

  tags = {
    Name = "DB Server"
  }
}

#WORDPRESS INSTANCE
resource "aws_instance" "wordpress" {
  ami = "ami-026b0985a69c8d08d"
  availability_zone = "ap-south-1a"
  instance_type = "t2.micro"
  key_name = "mykey"
  vpc_security_group_ids = [aws_security_group.wordpress_sec.id]
  subnet_id = aws_subnet.subnet_public.id
  associate_public_ip_address = true  

  tags = {
    Name = "WP Server"
  }
}

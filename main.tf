provider "aws" {
  region="us-east-1" # US East (N. Virginia) region
}

resource "aws_vpc" "demo" {
  cidr_block = var.cidr
}

resource "aws_subnet" "subnet1" {
  vpc_id            = aws_vpc.demo.id
  cidr_block        = "10.0.0.0/24"
  availability_zone = var.zone1
  map_public_ip_on_launch = true
}

resource "aws_subnet" "subnet2" {
  vpc_id            = aws_vpc.demo.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = var.zone2
  map_public_ip_on_launch = true
}

resource "aws_internet_gateway" "handson_ig" {
  vpc_id = aws_vpc.demo.id
}

resource "aws_route_table" "demo_route" {
  vpc_id = aws_vpc.demo.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.handson_ig.id
  }
}

resource "aws_route_table_association" "subnet1_association" {
  subnet_id      = aws_subnet.subnet1.id
  route_table_id = aws_route_table.demo_route.id
}

resource "aws_route_table_association" "subnet2_association" {
  subnet_id      = aws_subnet.subnet2.id
  route_table_id = aws_route_table.demo_route.id
}

resource "aws_security_group" "demogroup" {
  vpc_id = aws_vpc.demo.id

  ingress {
    description = "HTTP from vpc"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "demogroup"
  }
}
resource "aws_instance" "demo1" {
  ami                    = "ami-0e86e20dae9224db8"
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.demogroup.id]
  subnet_id              = aws_subnet.subnet1.id

  user_data = <<-EOF
              #!/bin/bash
              echo "<h1>Hello, World!</h1>" > /var/www/html/index.html
              yum install -y httpd
              systemctl start httpd
              systemctl enable httpd
              EOF
}

resource "aws_instance" "demo2" {
  ami                    = "ami-0e86e20dae9224db8"
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.demogroup.id]
  subnet_id              = aws_subnet.subnet2.id

  user_data = <<-EOF
              #!/bin/bash
              echo "<h1>Hello, there successfully created my second EC2 instance</h1>" > /var/www/html/index.html
              yum install -y httpd
              systemctl start httpd
              systemctl enable httpd
              EOF
}

resource "aws_lb" "example" {
  name               = "example-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.demogroup.id]
  subnets            = [aws_subnet.subnet1.id, aws_subnet.subnet2.id]
}

resource "aws_lb_target_group" "example" {
  name     = "example-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.demo.id

  health_check {
    path = "/"
    port = "traffic-port"
  }
}

resource "aws_lb_target_group_attachment" "attach1" {
  target_group_arn = aws_lb_target_group.example.arn
  target_id        = aws_instance.demo1.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "attach2" {
  target_group_arn = aws_lb_target_group.example.arn
  target_id        = aws_instance.demo2.id
  port             = 80
}

resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.example.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    target_group_arn = aws_lb_target_group.example.arn
    type             = "forward"
  }
}

output "loadbalancerdns" {
  value = aws_lb.example.dns_name
}

provider "aws" {
  profile = "default"
  region  = "us-west-2"
}

#RSA key of size 4096 bits
resource "tls_private_key" "keypair-4" {
  algorithm = "RSA"
  rsa_bits  = 4096
}
# creating private key
resource "local_file" "keypair-4" {
  content         = tls_private_key.keypair-4.private_key_pem
  filename        = "prom.pem"
  file_permission = "600"
}
# Creating ec2 keypair
resource "aws_key_pair" "keypair" {
  key_name   = "prom-keypair"
  public_key = tls_private_key.keypair-4.public_key_openssh
}

# security group for prometheus and grafana
resource "aws_security_group" "prom_graf_sg" {
  name        = "prom_graf_sg"
  description = "Allow Inbound Traffic"
  ingress {
    description = "ssh access"
    protocol    = "tcp"
    from_port   = 22
    to_port     = 22
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "prometheus_ui"
    protocol    = "tcp"
    from_port   = 9090
    to_port     = 9090
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "node_exporter_port"
    protocol    = "tcp"
    from_port   = 9100
    to_port     = 9100
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "grafana_ui"
    protocol    = "tcp"
    from_port   = 3000
    to_port     = 3000
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    name = "prom_graf_sg"
  }
}

# security group for target server
resource "aws_security_group" "target_server_sg" {
  name        = "target_server_sg"
  description = "Allow Inbound Traffic"
  ingress {
    description = "ssh access"
    protocol    = "tcp"
    from_port   = 22
    to_port     = 22
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "node_exporter_port"
    protocol    = "tcp"
    from_port   = 9100
    to_port     = 9100
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    name = "target_server_sg"
  }
}

# creating ec2 for prometheus and grafana
resource "aws_instance" "prom_graf" {
  ami                         = "ami-04dd23e62ed049936" //ubuntu
  instance_type               = "t2.medium"
  vpc_security_group_ids      = [aws_security_group.prom_graf_sg.id]
  key_name                    = aws_key_pair.keypair.id
  associate_public_ip_address = true
  user_data = templatefile("./install.sh", {
    nginx_webserver_ip = aws_instance.ec2.public_ip
  })
  depends_on = [aws_instance.ec2]

  tags = {
    Name = "promo_graf"
  }
}

# creating ec2
resource "aws_instance" "ec2" {
  ami                         = "ami-04dd23e62ed049936" //ubuntu
  instance_type               = "t2.micro"
  vpc_security_group_ids      = [aws_security_group.target_server_sg.id]
  key_name                    = aws_key_pair.keypair.id
  associate_public_ip_address = true
  user_data                   = file("./install2.sh")
  tags = {
    Name = "ec2-instance"
  }
}

output "prom-graf-ip" {
  value = aws_instance.prom_graf.public_ip
}

output "ec2-ip" {
  value = aws_instance.ec2.public_ip
}
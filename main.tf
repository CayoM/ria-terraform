terraform {
  required_providers {
    vault = {
      source = "hashicorp/vault"
      version = "5.3.0"
    }
    aws = {
      source = "hashicorp/aws"
      version = "6.0.0-beta2"
    }
  }
}

provider "vault" {
}

data "vault_kv_secret_v2" "mysecret" {
  mount = "secret"
  name  = "secrets"
}

provider "aws" {
  region     = var.aws_region
  access_key = data.vault_kv_secret_v2.mysecret.data["aws_access_key"]
  secret_key = data.vault_kv_secret_v2.mysecret.data["aws_secret_key"]
}

# Use default VPC
data "aws_vpc" "default" {
  default = true
}

# Find the latest Ubuntu 22.04 AMI
data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

locals {
  tcp_ports = {
    ssh = 22
    k8s = 6443
    web = 80
    ssl = 443
    kubecost = 9090
    hcm = 55671
    frontend = 30080
  }
  udp_ports = {
    snmp       = 161
    snmp_trap  = 162
  }
}

resource "aws_security_group" "allow_access" {
  name        = "${var.instance_name}-sg"
  description = "Allow SSH, HTTP, K8s API, HCM (TCP) and SNMP (UDP)"
  vpc_id      = data.aws_vpc.default.id

  # TCP-Regeln
  dynamic "ingress" {
    for_each = local.tcp_ports
    content {
      description = ingress.key
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = var.allowed_cidrs
    }
  }

  # UDP-Regeln (SNMP)
  dynamic "ingress" {
    for_each = local.udp_ports
    content {
      description = ingress.key
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "udp"
      cidr_blocks = var.allowed_cidrs
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


# Create key pair from a local public key file
resource "aws_key_pair" "ssh_key" {
  key_name   = "${var.instance_name}-ssh"
  public_key = data.vault_kv_secret_v2.mysecret.data["ssh_public_key"]
}

# EC2 instance
resource "aws_instance" "my_ec2_instance" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type

  key_name               = aws_key_pair.ssh_key.key_name
  vpc_security_group_ids = [aws_security_group.allow_access.id]

  root_block_device {
    volume_size = var.root_disk_size
    volume_type = "gp3"
  }

  tags = {
    Name = var.instance_name
    Role = var.role
  }
}

# Output public IP
output "instance_ip" {
  description = "Die öffentliche IP-Adresse der EC2-Instanz"
  value       = aws_instance.my_ec2_instance.public_ip
}
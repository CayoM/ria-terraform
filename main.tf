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
    aap = {
      source = "ansible/aap"
      version = "1.4.0-devpreview1"
    }
  }
}

provider "vault" {
  address = var.vault_url
  namespace = "admin"

  auth_login {
    path = "auth/approle/login"
    parameters = {
      role_id   = var.vault_role_id
      secret_id = var.vault_secret_id
    }
  }
}

ephemeral "vault_kv_secret_v2" "mysecret" {
  mount = "secret"
  name  = "secrets"
}

data "vault_kv_secret_v2" "mysecret" {
  mount = "secret"
  name  = "secrets"
}

provider "aws" {
  region     = var.aws_region
  access_key = ephemeral.vault_kv_secret_v2.mysecret.data["aws_access_key"]
  secret_key = ephemeral.vault_kv_secret_v2.mysecret.data["aws_secret_key"]
}

provider "aap" {
  host     = "https://${ephemeral.vault_kv_secret_v2.mysecret.data["awx_url"]}"
  username = "admin"
  password = ephemeral.vault_kv_secret_v2.mysecret.data["awx_admin_password"]
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

data "aap_inventory" "my_inventory" {
  name              = var.aap_inventory_name
  organization_name = var.aap_org_name
}

data "aap_job_template" "demo_job_template" {
  name              = var.aap_job_template_name
  organization_name = var.aap_org_name
}

resource "aap_job" "demo_job" {
  job_template_id = data.aap_job_template.demo_job_template.id
  inventory_id    = data.aap_inventory.my_inventory.id
  extra_vars      = yamlencode({ 
    "ec2_ip" : aws_instance.my_ec2_instance.public_ip,
    "instana_agent_key": data.vault_kv_secret_v2.mysecret.data["instana_agent_key"],
    "registry_pwd": data.vault_kv_secret_v2.mysecret.data["pull_secret"],
    "mesh_api_key": data.vault_kv_secret_v2.mysecret.data["hcm_mesh_api_key"],
    "instance_name": var.instance_name,
    "service_type": var.role,
    "location": var.ansible_var_location,
    "ansible_port": var.ansible_var_port,
    "remote_user": var.ansible_var_remote_user,
    "feature_kubecost": var.ansible_var_feature_kubecost,
    "feature_instana": var.ansible_var_feature_instana,
    "feature_sevone": var.ansible_var_feature_sevone,
    "feature_turbonomic": var.ansible_var_feature_turbonomic,
    "feature_hcm": var.ansible_var_feature_hcm,
    "app_name": var.ansible_var_app_name,
    "cloud_provider": var.ansible_var_cloud_provider
    })
  triggers = {
    instance_type = aws_instance.my_ec2_instance.instance_type
  }
}


# Output public IP
output "instance_ip" {
  description = "Die öffentliche IP-Adresse der EC2-Instanz"
  value       = aws_instance.my_ec2_instance.public_ip
}

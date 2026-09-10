terraform {
  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "5.3.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "vault" {
}

data "vault_kv_secret_v2" "mysecret" {
  mount = "secret"
  name  = "secrets"
}

provider "azurerm" {
  features {}

  subscription_id = data.vault_kv_secret_v2.mysecret.data["azure_subscription_id"]
  tenant_id       = data.vault_kv_secret_v2.mysecret.data["azure_tenant_id"]
  client_id       = data.vault_kv_secret_v2.mysecret.data["azure_client_id"]
  client_secret   = data.vault_kv_secret_v2.mysecret.data["azure_client_secret"]
}

# Azure kennt kein "Default VPC" wie AWS – RG/VNet/Subnet müssen explizit angelegt werden
resource "azurerm_resource_group" "main" {
  name     = "${var.instance_name}-rg"
  location = var.azure_location
}

resource "azurerm_virtual_network" "main" {
  name                = "${var.instance_name}-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_subnet" "main" {
  name                 = "${var.instance_name}-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.1.0/24"]
}

locals {
  tcp_ports = {
    ssh      = 22
    k8s      = 6443
    web      = 80
    ssl      = 443
    kubecost = 9090
    frontend = 30080
  }
  udp_ports = {
    snmp      = 161
    snmp_trap = 162
  }

  # NSG-Regeln brauchen anders als AWS SG-Ingress eine eindeutige numerische priority
  nsg_rules = merge(
    { for idx, name in keys(local.tcp_ports) : name => {
      port     = local.tcp_ports[name]
      protocol = "Tcp"
      priority = 100 + idx
    } },
    { for idx, name in keys(local.udp_ports) : name => {
      port     = local.udp_ports[name]
      protocol = "Udp"
      priority = 200 + idx
    } }
  )
}

resource "azurerm_network_security_group" "allow_access" {
  name                = "${var.instance_name}-nsg"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  dynamic "security_rule" {
    for_each = local.nsg_rules
    content {
      name                       = security_rule.key
      priority                   = security_rule.value.priority
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = security_rule.value.protocol
      source_port_range          = "*"
      destination_port_range     = tostring(security_rule.value.port)
      source_address_prefixes    = var.allowed_cidrs
      destination_address_prefix = "*"
    }
  }

  # Kein explizites Egress-Rule nötig: Azure NSGs erlauben Outbound per System-Default-Rule bereits
}

resource "azurerm_public_ip" "main" {
  name                = "${var.instance_name}-pip"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_interface" "main" {
  name                = "${var.instance_name}-nic"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.main.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.main.id
  }
}

resource "azurerm_network_interface_security_group_association" "main" {
  network_interface_id      = azurerm_network_interface.main.id
  network_security_group_id = azurerm_network_security_group.allow_access.id
}

# SSH-Key aus Vault, gleiches Feld wie beim AWS Key Pair
resource "azurerm_ssh_public_key" "ssh_key" {
  name                = "${var.instance_name}-ssh"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  public_key          = data.vault_kv_secret_v2.mysecret.data["ssh_public_key"]
}

# Azure VM (Entsprechung zur EC2-Instanz)
resource "azurerm_linux_virtual_machine" "my_vm_instance" {
  name                = var.instance_name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  size                = var.instance_type

  admin_username                  = "ubuntu"
  disable_password_authentication = true
  network_interface_ids           = [azurerm_network_interface.main.id]

  admin_ssh_key {
    username   = "ubuntu"
    public_key = azurerm_ssh_public_key.ssh_key.public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = var.root_disk_size
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  tags = {
    Name = var.instance_name
    Role = var.role
  }
}

# Output public IP
output "instance_ip" {
  description = "Die öffentliche IP-Adresse der Azure VM"
  value       = azurerm_public_ip.main.ip_address
}

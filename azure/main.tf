terraform {
  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "5.3.0"
    }
    turbonomic = {
      source  = "IBM/turbonomic"
      version = "1.0.2"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    aap = {
      source  = "ansible/aap"
      version = "1.4.0"
    }
  }
}

provider "vault" {
  address   = var.vault_url
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

provider "turbonomic" {
  username   = var.turbonomic_username
  password   = ephemeral.vault_kv_secret_v2.mysecret.data["turbonomic_password"]
  hostname   = ephemeral.vault_kv_secret_v2.mysecret.data["turbonomic_hostname"]
  skipverify = true
}

provider "azurerm" {
  features {}

  subscription_id = ephemeral.vault_kv_secret_v2.mysecret.data["azure_subscription_id"]
  tenant_id       = ephemeral.vault_kv_secret_v2.mysecret.data["azure_tenant_id"]
  client_id       = ephemeral.vault_kv_secret_v2.mysecret.data["azure_client_id"]
  client_secret   = ephemeral.vault_kv_secret_v2.mysecret.data["azure_client_secret"]
}

provider "aap" {
  host     = "https://${ephemeral.vault_kv_secret_v2.mysecret.data["awx_url"]}"
  username = "admin"
  password = ephemeral.vault_kv_secret_v2.mysecret.data["awx_admin_password"]
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

# Provider ist auf 1.0.2 gepinnt (wie im aws/-Verzeichnis) - die neueren, cloud-spezifischen
# Data Sources (z.B. turbonomic_azurerm_linux_virtual_machine) gibt es erst ab v1.5.0,
# daher hier bewusst der gleiche generische Data Source wie auf der AWS-Seite
data "turbonomic_cloud_entity_recommendation" "example" {
  entity_name = var.instance_name
  entity_type = "VirtualMachine"
}

# Azure VM (Entsprechung zur EC2-Instanz)
resource "azurerm_linux_virtual_machine" "my_vm_instance" {
  name                = var.instance_name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  # coalesce() statt != null, da Turbonomic für eine nicht gefundene Entity "" statt null liefert
  size = coalesce(data.turbonomic_cloud_entity_recommendation.example.new_instance_type, var.instance_type)

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
  extra_vars = yamlencode({
    # Key-Name "ec2_ip" bewusst beibehalten (nicht "vm_ip") - Ansible-Playbook/AAP-Seite liest diesen Key unabhängig von der Cloud
    "ec2_ip" : azurerm_public_ip.main.ip_address,
    "instana_agent_key" : data.vault_kv_secret_v2.mysecret.data["instana_agent_key"],
    "registry_pwd" : data.vault_kv_secret_v2.mysecret.data["pull_secret"],
    "instance_name" : var.instance_name,
    "service_type" : var.role,
    "ansible_port" : var.ansible_var_port,
    "remote_user" : var.ansible_var_remote_user,
    "feature_kubecost" : var.ansible_var_feature_kubecost,
    "feature_instana" : var.ansible_var_feature_instana,
    "feature_sevone" : var.ansible_var_feature_sevone,
    "feature_turbonomic" : var.ansible_var_feature_turbonomic,
    "app_name" : var.ansible_var_app_name,
    "cloud_provider" : var.ansible_var_cloud_provider
  })
  triggers = {
    instance_type = azurerm_linux_virtual_machine.my_vm_instance.size
  }
}

# Output public IP
output "instance_ip" {
  description = "Die öffentliche IP-Adresse der Azure VM"
  value       = azurerm_public_ip.main.ip_address
}

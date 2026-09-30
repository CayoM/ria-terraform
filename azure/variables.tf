variable "azure_location" {
  description = "Azure Region"
  type        = string
  default     = "westus3"
}

variable "allowed_cidrs" {
  description = "Liste der CIDRs, die Zugriff haben"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "environment_type" {
  description = "Umgebungstyp des Deployments (PROD, DEV, INT, STAGE) - wird als Tag gesetzt"
  type        = string
  default     = "DEV"

  validation {
    condition     = contains(["PROD", "DEV", "INT", "STAGE"], var.environment_type)
    error_message = "environment_type muss PROD, DEV, INT oder STAGE sein."
  }
}

variable "instance_name" {
  description = "Tag für die Instanz"
  type        = string
  default     = "UbuntuLatest"
}

variable "role" {
  description = "Rolle der Instanz (frontend, backend, db, ...)"
  type        = string
}

variable "root_disk_size" {
  description = "Disk size"
  type        = number
  default     = 100
}

variable "vault_url" {
  description = "HashiCorp Vault URL"
  type        = string
}

variable "vault_role_id" {
  description = "HashiCorp Vault Role ID"
  type        = string
}

variable "vault_secret_id" {
  description = "HashiCorp Vault Secret ID"
  type        = string
}

### AAP ###
variable "aap_org_name" {
  description = "Name of the Organization in AAP/AWX"
  type        = string
  default     = "Default"
}

variable "aap_job_template_name" {
  description = "Name of the Job Template in AAP/AWX"
  type        = string
  default     = "setup-ec2-instance-automated"
}

variable "aap_inventory_name" {
  description = "Name of the Inventory in AAP/AWX"
  type        = string
  default     = "Demo Inventory"
}
###########

### Ansible vars ###
variable "ansible_var_port" {
  type    = number
  default = 22
}

variable "ansible_var_remote_user" {
  type    = string
  default = "ubuntu"
}

variable "ansible_var_feature_kubecost" {
  type    = bool
  default = false
}

variable "ansible_var_feature_instana" {
  type    = bool
  default = false
}

variable "ansible_var_feature_sevone" {
  type    = bool
  default = false
}

variable "ansible_var_feature_turbonomic" {
  type    = bool
  default = true
}

variable "ansible_var_cloud_provider" {
  type    = string
  default = "Azure"
}

variable "ansible_var_app_name" {
  type    = string
  default = "robotshop"
}

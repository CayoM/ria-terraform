variable "aws_region" {
  description = "AWS Region"
  type        = string
  default     = "eu-central-1"
}

variable "public_key_path" {
  description = "Pfad zur lokalen SSH Public Key Datei"
  type        = string
  default     = "./id_rsa.pub"
}

variable "allowed_cidrs" {
  description = "Liste der CIDRs, die Zugriff haben"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "instance_type" {
  description = "EC2 Instance Type"
  type        = string
  default     = "t2.2xlarge"
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
  type        = number
  default     = 22
}

variable "ansible_var_location" {
  type        = string
  default     = "south"
}

variable "ansible_var_remote_user" {
  type        = string
  default     = "ubuntu"
}

variable "ansible_var_feature_kubecost" {
  type        = bool
  default     = false
}

variable "ansible_var_feature_instana" {
  type        = bool
  default     = false
}

variable "ansible_var_feature_sevone" {
  type        = bool
  default     = false
}

variable "ansible_var_feature_hcm" {
  type        = bool
  default     = false
}

variable "ansible_var_cloud_provider" {
  type        = string
  default     = "AWS"
}

variable "ansible_var_app_name" {
  type        = string
  default     = "robotshop"
}
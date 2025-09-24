variable "turbonomic_username" {
  description = "Turbonomic Login User"
  type        = string
  default     = "administrator"
}

variable "aws_region" {
  description = "AWS Region"
  type        = string
  default     = "eu-central-1"
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
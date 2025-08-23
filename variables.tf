variable "turbonomic_hostname" {
  description = "Turbonomic URL"
  type        = string
}

variable "turbonomic_password" {
  description = "Turbonomic User Password"
  type        = string
  sensitive   = true
}

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

variable "aws_access_key" {
  description = "AWS Access Key"
  type        = string
  sensitive   = true
}

variable "aws_secret_key" {
  description = "AWS Secret Key"
  type        = string
  sensitive   = true
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
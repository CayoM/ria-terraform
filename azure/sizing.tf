# VM-Size-Auswahl: nur gültige Azure-Sizes (Standard_*) erreichen die API.
# instance_type kommt u.U. aus AAP bzw. einem mit AWS geteilten Variable-Set (z.B. "t3.2xlarge").
locals {
  default_vm_size    = "Standard_D4ads_v6"
  azure_size_pattern = "^Standard_[A-Za-z0-9_-]+$"

  requested_vm_size = can(regex(local.azure_size_pattern, var.instance_type)) ? var.instance_type : local.default_vm_size

  vm_size = local.requested_vm_size
}

check "instance_type_is_azure_size" {
  assert {
    condition     = can(regex(local.azure_size_pattern, var.instance_type))
    error_message = "instance_type \"${coalesce(var.instance_type, "null")}\" ist keine Azure VM Size (Standard_*) - verwende Fallback ${local.default_vm_size}."
  }
}

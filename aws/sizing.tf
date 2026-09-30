# Instance-Type-Auswahl: nur gültige EC2-Typen (<familie>.<größe>, z.B. t3.2xlarge) erreichen die API.
# instance_type kommt u.U. aus AAP bzw. einem mit Azure geteilten Variable-Set (z.B. "Standard_D4ads_v6").
locals {
  default_instance_type = "t2.2xlarge"
  ec2_type_pattern      = "^[a-z][a-z0-9-]*\\.[a-z0-9-]+$"

  requested_instance_type = can(regex(local.ec2_type_pattern, var.instance_type)) ? var.instance_type : local.default_instance_type

  ec2_instance_type = local.requested_instance_type
}

check "instance_type_is_ec2_type" {
  assert {
    condition     = can(regex(local.ec2_type_pattern, var.instance_type))
    error_message = "instance_type \"${coalesce(var.instance_type, "null")}\" ist kein EC2 Instance Type (<familie>.<größe>) - verwende Fallback ${local.default_instance_type}."
  }
}

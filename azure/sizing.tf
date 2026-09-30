# Feste VM-Size; eine gültige Turbonomic-Empfehlung überschreibt sie.
# Der generische Turbonomic-Data-Source filtert nicht nach Cloud - bei Namensgleichheit
# mit einer AWS-VM liefert er deren AWS-Empfehlung, daher die Format-Prüfung.
locals {
  default_vm_size    = "Standard_D4ads_v6"
  azure_size_pattern = "^Standard_[A-Za-z0-9_-]+$"

  # Turbonomic liefert für eine nicht gefundene Entity "" statt null
  turbonomic_size = data.turbonomic_cloud_entity_recommendation.example.new_instance_type
  vm_size         = can(regex(local.azure_size_pattern, coalesce(local.turbonomic_size, "-"))) ? local.turbonomic_size : local.default_vm_size
}

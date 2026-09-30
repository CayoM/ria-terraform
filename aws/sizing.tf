# Fester Instance-Type; eine gültige Turbonomic-Empfehlung überschreibt ihn.
# Der generische Turbonomic-Data-Source filtert nicht nach Cloud - bei Namensgleichheit
# mit einer Azure-VM liefert er deren Azure-Empfehlung, daher die Format-Prüfung.
locals {
  default_instance_type = "t3.2xlarge"
  ec2_type_pattern      = "^[a-z][a-z0-9-]*\\.[a-z0-9-]+$"

  # Turbonomic liefert für eine nicht gefundene Entity "" statt null
  turbonomic_type   = data.turbonomic_cloud_entity_recommendation.example.new_instance_type
  ec2_instance_type = can(regex(local.ec2_type_pattern, coalesce(local.turbonomic_type, "-"))) ? local.turbonomic_type : local.default_instance_type
}

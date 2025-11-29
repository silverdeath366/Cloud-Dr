output "fqdn" {
  description = "Traffic Manager FQDN"
  value       = azurerm_traffic_manager_profile.main.fqdn
}

output "profile_id" {
  description = "Traffic Manager profile ID"
  value       = azurerm_traffic_manager_profile.main.id
}


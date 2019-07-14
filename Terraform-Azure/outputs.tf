output "region" {
  value = var.region
}

output "logger_public_ip" {
  value = azurerm_public_ip.logger.ip_address
}

output "dc_public_ip" {
  value = azurerm_public_ip.dc.ip_address
}

output "wef_public_ip" {
  value = azurerm_public_ip.wef.ip_address
}

output "win10_public_ip" {
  value = azurerm_public_ip.win10.ip_address 
}

output "ata_url" {
  value = local.ata_url
}

output "fleet_url" {
  value = local.fleet_url
}

output "splunk_url" {
  value = local.splunk_url
}

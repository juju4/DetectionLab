locals {
  fleet_url  = "https://${azurerm_public_ip.logger.ip_address}:8412"
  splunk_url = "https://${azurerm_public_ip.logger.ip_address}:8000"
  ata_url    = "https://${azurerm_public_ip.wef.ip_address}"
}

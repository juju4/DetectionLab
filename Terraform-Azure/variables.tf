variable "region" {
  default = "useast"
}

variable "profile" {
  default = "terraform"
}

variable "availability_zone" {
  description = "https://docs.microsoft.com/en-us/azure/availability-zones/az-overview"
  default     = ""
}

variable "shared_credentials_file" {
  description = "Path to your Azure credentials file"
  type        = string
  default     = "/home/username/.azure/credentials"
}

variable "public_key_name" {
  description = "A name for SSH Keypair to use to auth to logger. Can be anything you specify."
  default     = "id_logger"
}

variable "public_key_path" {
  description = "Path to the public key to be loaded into the logger authorized_keys file"
  type        = string
  default     = "/home/username/.ssh/id_logger.pub"
}

variable "private_key_path" {
  description = "Path to the private key to use to authenticate to logger."
  type        = string
  default     = "/home/username/.ssh/id_logger"
}

variable "ip_whitelist" {
  description = "A list of CIDRs that will be allowed to access the instances"
  type        = list(string)
  default     = [""]
}

variable "external_dns_servers" {
  description = "Configure lab to allow external DNS resolution"
  type        = list(string)
  default     = ["8.8.8.8"]
}

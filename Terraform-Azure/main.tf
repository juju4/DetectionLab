# terraform init, plan, apply, destroy
# Note: does not support idempotence, don't execute twice with same scope.
# https://www.terraform.io/docs/providers/azurerm/index.html
# latest test: terraform 0.12.7
#
# FIXME!
# * apply: provisioning not working on Windows
# Error: Unsupported argument [...] An argument named "connection" is not expected here.
#    apply => Error: timeout - last error: SSH authentication failed (root@:22): ssh: handshake failed: ssh: unable to authenticate, attempted methods [none publickey], no supported methods remain
# * apply: linux provisioning
#	=> works but script ends with error code for some reason (post bro install and splunk restart)

# Specify the provider and access details
provider "azurerm" {
  version = "~>1.33"
#  region                  = var.region
}

resource "azurerm_resource_group" "Terraform0rg" {
  name = "DetectionLab0terraform"
  location = "eastus"
  tags = {
    environment = "DetectionLab Azure Demo"
  }
}

resource "azurerm_virtual_network" "Terraform0network" {
  name = "DetectionLab0Vnet"
  address_space = ["192.168.0.0/16"]
  location = "eastus"
  resource_group_name = "${azurerm_resource_group.Terraform0rg.name}"
}

# Create a subnet to launch our instances into
resource "azurerm_subnet" "Terraform0subnet" {
  name                 = "DetectionLab0Subnet"
  resource_group_name  = "${azurerm_resource_group.Terraform0rg.name}"
  virtual_network_name = "${azurerm_virtual_network.Terraform0network.name}"
  address_prefix       = "192.168.38.0/24"
}

resource "azurerm_network_security_group" "Terraform0nsg" {
  name                = "DetectionLab0nsg"
  location = "eastus"
  resource_group_name  = "${azurerm_resource_group.Terraform0rg.name}"

  # SSH access
  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    # source_address_prefix      = "*"
    source_address_prefixes    = var.ip_whitelist
    destination_address_prefix = "*"
  }

  # Splunk access
  security_rule {
    name                       = "Splunk"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8000"
    source_address_prefixes    = var.ip_whitelist
    destination_address_prefix = "*"
  }

  # Fleet access
  security_rule {
    name                       = "Fleet"
    priority                   = 1003
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8412"
    source_address_prefixes    = var.ip_whitelist
    destination_address_prefix = "*"
  }

  # RDP
  security_rule {
    name                       = "RDP"
    priority                   = 1004
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefixes    = var.ip_whitelist
    destination_address_prefix = "*"
  }

  # WinRM
  security_rule {
    name                       = "WinRM"
    priority                   = 1005
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5986"
    source_address_prefixes    = var.ip_whitelist
    destination_address_prefix = "*"
  }

  # Windows ATA
  security_rule {
    name                       = "WindowsATA"
    priority                   = 1006
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefixes    = var.ip_whitelist
    destination_address_prefix = "*"
  }

  # Allow all traffic from the private subnet
  security_rule {
    name                       = "PrivateSubnet"
    priority                   = 1007
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "192.168.38.0/24"
    destination_address_prefix = "*"
  }

}

resource "azurerm_public_ip" "logger" {
  name                = "DetectionLab0PublicIP0logger"
  location            = "eastus"
  resource_group_name = "${azurerm_resource_group.Terraform0rg.name}"
  allocation_method   = "Static"

  tags = {
    environment = "DetectionLab Azure Demo"
    role = "logger"
  }
}

resource "azurerm_network_interface" "Terraform0nic" {
  name                = "DetectionLab0NIC0logger"
  location            = "eastus"
  resource_group_name = "${azurerm_resource_group.Terraform0rg.name}"

  ip_configuration {
    name                          = "myNicConfiguration"
    subnet_id                     = "${azurerm_subnet.Terraform0subnet.id}"
    private_ip_address_allocation = "Static"
    private_ip_address            = "192.168.38.105"
    public_ip_address_id          = "${azurerm_public_ip.logger.id}"
  }
}

# Storage
resource "random_id" "randomId" {
  keepers = {
    # Generate a new ID only when a new resource group is defined
    resource_group_name  = "${azurerm_resource_group.Terraform0rg.name}"
  }
  byte_length = 8
}

resource "azurerm_storage_account" "Terraform0storageaccount" {
  name                = "diag${random_id.randomId.hex}"
  location = "eastus"
  resource_group_name  = "${azurerm_resource_group.Terraform0rg.name}"
  account_replication_type = "LRS"
  account_tier = "Standard"
}

# Linux VM
resource "azurerm_virtual_machine" "Terraform0logger" {
  name = "logger"
  location = "eastus"
  resource_group_name  = "${azurerm_resource_group.Terraform0rg.name}"
  network_interface_ids = ["${azurerm_network_interface.Terraform0nic.id}"]
  vm_size               = "Standard_DS1_v2"

  delete_os_disk_on_termination = true

  storage_os_disk {
    name              = "OsDiskLogger"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    #sku       = "18.04.0-LTS"
    sku       = "16.04.0-LTS"
    version   = "latest"
  }

  os_profile {
    computer_name  = "logger"
    admin_username = "azureuser"
    admin_password = "${var.linux_admin_password}"
  }

  os_profile_linux_config {
    disable_password_authentication = true
    ssh_keys {
      path     = "/home/azureuser/.ssh/authorized_keys"
      key_data = file(var.public_key_path)
    }
  }

  boot_diagnostics {
    enabled     = "true"
    storage_uri = "${azurerm_storage_account.Terraform0storageaccount.primary_blob_endpoint}"
  }

  # Provision
  # https://github.com/terraform-providers/terraform-provider-azurerm/blob/master/examples/virtual-machines/provisioners/linux/main.tf
  # https://www.terraform.io/docs/provisioners/connection.html
  provisioner "remote-exec" {
    connection {
      host = "${azurerm_public_ip.logger.ip_address}"
      user     = "azureuser"
      # password = "${local.admin_password}"
      private_key = file(var.private_key_path)
      # agent = false
      # timeout = "10m"
    }
    inline = [
      "sudo add-apt-repository universe && sudo apt-get -qq update && sudo apt-get -qq install -y git",
      "echo 'logger' | sudo tee /etc/hostname && sudo hostnamectl set-hostname logger",
      "sudo adduser --disabled-password --gecos \"\" vagrant && echo 'vagrant:vagrant' | sudo chpasswd",
      "sudo mkdir /home/vagrant/.ssh && sudo cp /home/ubuntu/.ssh/authorized_keys /home/vagrant/.ssh/authorized_keys && sudo chown -R vagrant:vagrant /home/vagrant/.ssh",
      "echo 'vagrant    ALL=(ALL:ALL) NOPASSWD:ALL' | sudo tee -a /etc/sudoers",
      "sudo git clone https://github.com/clong/DetectionLab.git /opt/DetectionLab",
      "sudo sed -i 's/eth1/eth0/g' /opt/DetectionLab/Vagrant/bootstrap.sh",
      "sudo sed -i 's/ETH1/ETH0/g' /opt/DetectionLab/Vagrant/bootstrap.sh",
      "sudo sed -i 's#/usr/local/go/bin/go get -u#GOPATH=/root/go /usr/local/go/bin/go get -u#g' /opt/DetectionLab/Vagrant/bootstrap.sh",
      "sudo sed -i 's#/vagrant/resources#/opt/DetectionLab/Vagrant/resources#g' /opt/DetectionLab/Vagrant/bootstrap.sh",
      "sudo chmod +x /opt/DetectionLab/Vagrant/bootstrap.sh",
      "sudo apt-get -qq update",
      "sudo /opt/DetectionLab/Vagrant/bootstrap.sh 2>&1 | tee /opt/DetectionLab/Vagrant/bootstrap.log",
    ]
  }

  tags = {
    environment = "DetectionLab Azure Demo"
    role = "logger"
  }
}

# https://github.com/terraform-providers/terraform-provider-azurerm/tree/master/examples/virtual-machines/vm-joined-to-active-directory

# Windows VM
resource "azurerm_network_interface" "Terraform0nic2" {
  name = "DetectionLab0NIC0dc"
  location = "eastus"
  resource_group_name  = "${azurerm_resource_group.Terraform0rg.name}"

  ip_configuration {
    name                          = "myNicConfiguration"
    subnet_id                     = "${azurerm_subnet.Terraform0subnet.id}"
    private_ip_address_allocation = "Static"
    private_ip_address            = "192.168.38.102"
    public_ip_address_id          = "${azurerm_public_ip.dc.id}"
  }
}

resource "azurerm_public_ip" "dc" {
  name                = "DetectionLab0PublicIP0dc"
  location            = "eastus"
  resource_group_name = "${azurerm_resource_group.Terraform0rg.name}"
  allocation_method   = "Static"

  tags = {
    environment = "DetectionLab Azure Demo"
    role = "dc"
  }
}

resource "azurerm_network_interface" "Terraform0nic3" {
  name = "DetectionLab0NIC0wef"
  location = "eastus"
  resource_group_name  = "${azurerm_resource_group.Terraform0rg.name}"

  ip_configuration {
    name                          = "myNicConfiguration"
    subnet_id                     = "${azurerm_subnet.Terraform0subnet.id}"
    private_ip_address_allocation = "Static"
    private_ip_address            = "192.168.38.103"
    public_ip_address_id          = "${azurerm_public_ip.wef.id}"
  }
}

resource "azurerm_public_ip" "wef" {
  name                = "DetectionLab0PublicIP0wef"
  location            = "eastus"
  resource_group_name = "${azurerm_resource_group.Terraform0rg.name}"
  allocation_method   = "Static"

  tags = {
    environment = "DetectionLab Azure Demo"
    role = "wef"
  }
}

resource "azurerm_network_interface" "Terraform0nic4" {
  name = "DetectionLab0NIC0win10"
  location = "eastus"
  resource_group_name  = "${azurerm_resource_group.Terraform0rg.name}"

  ip_configuration {
    name                          = "myNicConfiguration"
    subnet_id                     = "${azurerm_subnet.Terraform0subnet.id}"
    private_ip_address_allocation = "Static"
    private_ip_address            = "192.168.38.104"
    public_ip_address_id          = "${azurerm_public_ip.win10.id}"
  }
}

resource "azurerm_public_ip" "win10" {
  name                = "DetectionLab0PublicIP0win10"
  location            = "eastus"
  resource_group_name = "${azurerm_resource_group.Terraform0rg.name}"
  allocation_method   = "Static"

  tags = {
    environment = "DetectionLab Azure Demo"
    role = "win10"
  }
}

resource "azurerm_virtual_machine" "Terraform0dc" {
  name = "dc.windomain.local"
  location = "eastus"
  resource_group_name  = "${azurerm_resource_group.Terraform0rg.name}"
  network_interface_ids = ["${azurerm_network_interface.Terraform0nic2.id}"]
  vm_size               = "Standard_DS1_v2"

  delete_os_disk_on_termination = true

  storage_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2016-Datacenter"
    version   = "latest"
  }

  os_profile {
    computer_name  = "dc"
    admin_username = "azureuser"
    admin_password = "${var.win_admin_password}"
  }
  os_profile_windows_config {
    provision_vm_agent        = true
    enable_automatic_upgrades = true

    # https://www.terraform.io/docs/providers/azurerm/r/virtual_machine.html#winrm
    #winrm = {
    #  protocol = 'HTTPS'
    #}

    # Auto-Login's required to configure WinRM
    additional_unattend_config {
      pass         = "oobeSystem"
      component    = "Microsoft-Windows-Shell-Setup"
      setting_name = "AutoLogon"
      content      = "<AutoLogon><Password><Value>${var.win_admin_password}</Value></Password><Enabled>true</Enabled><LogonCount>1</LogonCount><Username>azureuser</Username></AutoLogon>"
    }

    # Unattend config is to enable basic auth in WinRM, required for the provisioner stage.
    # https://github.com/terraform-providers/terraform-provider-azurerm/blob/master/examples/virtual-machines/provisioners/windows/files/FirstLogonCommands.xml
    additional_unattend_config {
      pass         = "oobeSystem"
      component    = "Microsoft-Windows-Shell-Setup"
      setting_name = "FirstLogonCommands"
      content      = "${file("./files/FirstLogonCommands.xml")}"
    }
  }

  storage_os_disk {
    name              = "OsDiskDc"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  tags = {
    environment = "DetectionLab Azure Demo"
    role = "dc"
  }

  # https://github.com/terraform-providers/terraform-provider-azurerm/blob/master/examples/virtual-machines/provisioners/windows/main.tf
  provisioner "file" {
    source     = "${path.module}/scripts/"
    destination = "C:/scripts"
## Error: Unsupported argument [...] An argument named "connection" is not expected here.
##    apply => Error: timeout - last error: SSH authentication failed (root@:22): ssh: handshake failed: ssh: unable to authenticate, attempted methods [none publickey], no supported methods remain
#    connection   = {
#      host = self.public_ip
#      type       = "winrm"
#      user       = "${azurerm_virtual_machine.Terraform0dc.admin_username}"
#      password   = "${var.win_admin_password}"
#      timeout    = "10m"
#      # NOTE: if you're using a real certificate, rather than a self-signed one, you'll want this set to `false`/to remove this.
#      insecure = true
#    }
  }
  provisioner "remote-exec" {
## Error: Unsupported argument [...] An argument named "connection" is not expected here.
#    connection   = {
#      host = self.public_ip
#      type       = "winrm"
#      user       = "${azurerm_virtual_machine.Terraform0dc.admin_username}"
#      password   = "${var.win_admin_password}"
#      timeout    = "10m"
#      # NOTE: if you're using a real certificate, rather than a self-signed one, you'll want this set to `false`/to remove this.
#      insecure = true
#    }
    inline = [
      #"powershell.exe Set-ExecutionPolicy RemoteSigned -force",
      "powershell.exe -version 5 -ExecutionPolicy Bypass -File C:/scripts/provision.ps1"
    ]
  }
}

resource "azurerm_virtual_machine" "Terraform0wef" {
  name = "wef.windomain.local"
  location = "eastus"
  resource_group_name  = "${azurerm_resource_group.Terraform0rg.name}"
  network_interface_ids = ["${azurerm_network_interface.Terraform0nic3.id}"]
  vm_size               = "Standard_DS1_v2"

  delete_os_disk_on_termination = true

  storage_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2016-Datacenter"
    version   = "latest"
  }

  os_profile {
    computer_name  = "wef"
    admin_username = "azureuser"
    admin_password = "${var.win_admin_password}"
  }
  os_profile_windows_config {
    enable_automatic_upgrades = true
  }

  storage_os_disk {
    name              = "OsDiskWef"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  tags = {
    environment = "DetectionLab Azure Demo"
    role = "wef"
  }
}

resource "azurerm_virtual_machine" "Terraform0win10" {
  name = "win10.windomain.local"
  location = "eastus"
  resource_group_name  = "${azurerm_resource_group.Terraform0rg.name}"
  network_interface_ids = ["${azurerm_network_interface.Terraform0nic4.id}"]
  vm_size               = "Standard_DS1_v2"

  delete_os_disk_on_termination = true

  storage_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2016-Datacenter"
    version   = "latest"
  }

  os_profile {
    computer_name  = "win10"
    admin_username = "azureuser"
    admin_password = "${var.win_admin_password}"
  }
  os_profile_windows_config {
    enable_automatic_upgrades = true
    provision_vm_agent = true
    # https://www.terraform.io/docs/providers/azurerm/r/virtual_machine.html#winrm
    #winrm = {
    #  protocol = 'HTTPS'
    #}
  }

  storage_os_disk {
    name              = "OsDiskWin10"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  tags = {
    environment = "DetectionLab Azure Demo"
    role = "win10"
  }
}

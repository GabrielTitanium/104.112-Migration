################################
# Providers
################################
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    random = {
      source = "hashicorp/random"
    }
  }

  backend "azurerm" {
    resource_group_name  = "tfstate-rg"
    storage_account_name = "tfstateorigin123"
    container_name       = "tfstate"
    key                  = "Salud-112.tfstate"
    use_azuread_auth     = true
  }
}

provider "azurerm" {
  features {}
}

################################
# Variables
################################
variable "server_name" {
  default = "Salud-112"
}

variable "shared_resource_group_name" {
  default = "test_terraform_rgroup"
}

variable "admin_username" {
  default = "titaniumTTH793"
}

variable "admin_password" {
  description = "Password for the Windows VM admin user"
  sensitive   = true
}

variable "storage_account_name" {
  description = "Name of the storage account where the setup.ps1 script is stored"
}

# User-assigned identity the VM uses to download setup.ps1, instead of a storage
# account key (same as DVOP-ServerDeploy). It exists in the shared resource group
# with Storage Blob Data Reader on the pwscripts "test" container only.
variable "scripts_identity_name" {
  description = "User-assigned identity that can read setup.ps1 in the storage account"
  type        = string
  default     = "id-terraform-vm-scripts"
}

################################
# Random suffix
################################
resource "random_id" "suffix" {
  byte_length = 4
}

################################
# EXISTING IMAGE (GENERALIZED)
################################
data "azurerm_image" "migration_image" {
  name                = "Salud-112-image"
  resource_group_name = var.shared_resource_group_name
}

################################
# EXISTING SHARED NETWORK
################################
data "azurerm_virtual_network" "existing_vnet" {
  name                = "main-vnet"
  resource_group_name = var.shared_resource_group_name
}

data "azurerm_subnet" "existing_subnet" {
  name                 = "main-subnet"
  virtual_network_name = data.azurerm_virtual_network.existing_vnet.name
  resource_group_name  = var.shared_resource_group_name
}

data "azurerm_network_security_group" "existing_nsg" {
  name                = "main-nsg"
  resource_group_name = var.shared_resource_group_name
}

data "azurerm_user_assigned_identity" "scripts" {
  name                = var.scripts_identity_name
  resource_group_name = var.shared_resource_group_name
}

################################
# EXISTING PERMANENT PUBLIC IP
# Created manually in Azure portal once - never created or destroyed by Terraform
################################
data "azurerm_public_ip" "existing_pip" {
  name                = "Salud-112-pip"
  resource_group_name = var.shared_resource_group_name
}

################################
# TEMP RESOURCE GROUP (AUTO DELETE)
################################
resource "azurerm_resource_group" "vm_rg" {
  name     = "tmp-${var.server_name}-${random_id.suffix.hex}"
  location = data.azurerm_virtual_network.existing_vnet.location

  tags = {
    AutoDelete     = "true"
    ExpirationDate = formatdate("YYYY-MM-DD", timeadd(timestamp(), "1h"))
  }
}

################################
# NETWORK INTERFACE
################################
resource "azurerm_network_interface" "nic" {
  name                = "${var.server_name}-nic-${random_id.suffix.hex}"
  resource_group_name = azurerm_resource_group.vm_rg.name
  location            = azurerm_resource_group.vm_rg.location

  ip_configuration {
    name                          = "internal"
    subnet_id                     = data.azurerm_subnet.existing_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = data.azurerm_public_ip.existing_pip.id
  }
}

resource "azurerm_network_interface_security_group_association" "nsg_assoc" {
  network_interface_id      = azurerm_network_interface.nic.id
  network_security_group_id = data.azurerm_network_security_group.existing_nsg.id
}

################################
# WINDOWS VM (FROM CUSTOM IMAGE)
################################
resource "azurerm_windows_virtual_machine" "vm" {
  name          = var.server_name
  computer_name = var.server_name

  resource_group_name = azurerm_resource_group.vm_rg.name
  location            = azurerm_resource_group.vm_rg.location
  size                = "Standard_B2s"

  admin_username = var.admin_username
  admin_password = var.admin_password

  network_interface_ids = [
    azurerm_network_interface.nic.id
  ]
  identity {
    type         = "UserAssigned"
    identity_ids = [data.azurerm_user_assigned_identity.scripts.id]
  }


  os_disk {
    name                 = "${var.server_name}-osdisk-${random_id.suffix.hex}"
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
  }

  source_image_id = data.azurerm_image.migration_image.id

  provision_vm_agent       = true
  enable_automatic_updates = true

  boot_diagnostics {
    storage_account_uri = null
  }
}

################################
# CUSTOM SCRIPT EXTENSION
################################
resource "azurerm_virtual_machine_extension" "setup_script" {
  name                 = "customScriptExtension"
  virtual_machine_id   = azurerm_windows_virtual_machine.vm.id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"

  depends_on = [
    azurerm_windows_virtual_machine.vm
  ]

  settings = <<SETTINGS
{
  "commandToExecute": "powershell.exe -ExecutionPolicy Unrestricted -File setup.ps1 -newServerName ${var.server_name}"
}
SETTINGS

  protected_settings = <<PROTECTED_SETTINGS
{
  "managedIdentity": { "clientId": "${data.azurerm_user_assigned_identity.scripts.client_id}" },
  "fileUris": [
    "https://${var.storage_account_name}.blob.core.windows.net/test/setup.ps1"
  ]
}
PROTECTED_SETTINGS
}

################################
# Outputs
################################
output "public_ip" {
  value       = data.azurerm_public_ip.existing_pip.ip_address
  description = "The permanent public IP address for Salud-112"
}

output "vm_resource_group" {
  value       = azurerm_resource_group.vm_rg.name
  description = "The temporary resource group created for this VM"
}

output "server_fqdn" {
  value       = "salud-112.environments.titanium.solutions"
  description = "The FQDN for the Salud-112 server"
}

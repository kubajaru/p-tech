terraform {
  required_version = ">= 0.14"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.11.0"
    }
  }
}

provider "azurerm" {
  subscription_id = "58bd169e-f010-4552-ac52-1a03abe0a576"
  features {}
}

data "azurerm_resource_group" "tfexample" {
  name = "p-tech-workshops"
}

resource "azurerm_virtual_network" "tfexample" {
  name                = "main"
  location            = data.azurerm_resource_group.tfexample.location
  resource_group_name = data.azurerm_resource_group.tfexample.name
  address_space       = ["10.0.0.0/16"]
}

# Create a Subnet in the Virtual Network
resource "azurerm_subnet" "tfexample" {
  name                 = "main"
  resource_group_name  = data.azurerm_resource_group.tfexample.name
  virtual_network_name = azurerm_virtual_network.tfexample.name
  address_prefixes     = ["10.0.0.0/24"]
}

variable "number_of_vms" {
  type = number
}

variable "admin_password" {
  type      = string
  sensitive = true
}

resource "azurerm_public_ip" "main" {
  count               = var.number_of_vms
  name                = "student${count.index}-pip"
  resource_group_name = data.azurerm_resource_group.tfexample.name
  location            = data.azurerm_resource_group.tfexample.location
  allocation_method   = "Static"
}

# Create a Network Interface
resource "azurerm_network_interface" "tfexample" {
  count               = var.number_of_vms
  name                = "student${count.index}-nic"
  location            = data.azurerm_resource_group.tfexample.location
  resource_group_name = data.azurerm_resource_group.tfexample.name

  ip_configuration {
    name                          = "student${count.index}-ip-config"
    subnet_id                     = azurerm_subnet.tfexample.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.main[count.index].id
  }

}

# Create a Virtual Machine
resource "azurerm_linux_virtual_machine" "tfexample" {
  count                           = var.number_of_vms
  name                            = "student${count.index}-vm"
  location                        = data.azurerm_resource_group.tfexample.location
  resource_group_name             = data.azurerm_resource_group.tfexample.name
  network_interface_ids           = [azurerm_network_interface.tfexample[count.index].id]
  size                            = "Standard_DS1_v2"
  computer_name                   = "myvm"
  admin_username                  = "azureuser"
  admin_password                  = var.admin_password
  disable_password_authentication = false
  priority                        = "Spot"
  eviction_policy                 = "Deallocate"

  custom_data = base64encode(file("./nginx.sh"))

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts-gen2"
    version   = "latest"
  }

  os_disk {
    name                 = "student${count.index}-disk"
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
  }
}


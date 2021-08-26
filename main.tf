# Configure the Azure provider
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 2.65"
    }
  }

  required_version = ">= 0.14.9"
}

provider "azurerm" {
  features {}
}

#Group resource
resource "azurerm_resource_group" "rg-govin" {
  name     = "rg-govin"
  location = "westeurope"
}

#Virtual Network
resource "azurerm_virtual_network" "rg-govin-network" {
  name                = "rg-govin-network"
  address_space       = ["10.0.0.0/16"]
  location            = "westeurope"
  resource_group_name = azurerm_resource_group.rg-govin.name

  tags = {
    environnment = "Terraform test"
  }
}

#Create public IPs
resource "azurerm_public_ip" "rg-govin-publicip" {
  name                = "govin-public-ip"
  localtion           = "westeurope"
  resource_group_name = azurerm_resource_group.rg-govin.name
  allocation_method   = "Dynamic"

  tags = {
    environment = "Terraform test"
  }
}

#Network Security Group and rule
resource "azurerm_network_security_group" "rg-govin-nsg" {
  name                = "govinNetworkSecurityGroup"
  location            = "westeurope"
  resource_group_name = azurerm_resource_group.rg-govin.name

  security_rule {
    name                   = "SSH"
    priority               = 1001
    direction              = "Inbound"
    access                 = "Allow"
    protocol               = "Tcp"
    source_port_range      = "*"
    destination_port_range = "22"
    source_address_prefix  = "*"
  }

  tags = {
    environment = "Terraform test"
  }
}

#Create network interface
resource "azurerm_network_interface" "rg-govin-nic" {
  name                = "rg-govin-NIC"
  location            = "westeurope"
  resource_group_name = azurerm_resource_group.rg-govin.name

  ip_configuration {
    name                          = "rg-govin-NicConfiguration"
    subnet_id                     = azurerm_resource_group.rg-govin.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.rg-govin-publicip.id
  }

  tags {
    environment = "Terraform test"
  }
}

#Connect security group to the network interface
resource "azurerm_network_interface_security_group_association" "rg-govin-nic-sga" {
  network_interface_id      = azurerm_network_interface.rg-govin-nic.id
  network_security_group_id = azurerm_network_security_group.rg-govin-nsg.id
}

#Generate random text for a unique sotrage account name
resource "random_id" "randomId" {
  keepers = {
    #Generate a new ID only when a new resource group is defined
    resource_group = azurerm_resource_group.rg-govin.name
  }

  byte_length = 8
}

#Create storage account for boot diagnostics
resource "azurerm_storage_account" "rg-govin-storageaccount" {
  name                     = "diag${random_id.randomId.hex}"
  resource_group_name      = azurerm_resource_group.rg-govin.name
  location                 = "westeurope"
  account_tier             = "Standard"
  account_replication_type = "LRS"

  tags = {
    environment = "Terraform test"
  }
}

#Create (and display) an SSH key
resource "tls_private_key" "rg-govin_ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}
output "tls_private_key" {
  value     = tls_private_key.rg-govin_ssh.private_key_pem
  sensitive = true
}

#Create virtual machine
resource "azurerm_linux_virtual_machine" "rg-govin-linuxvm" {
  name                  = "rg-govin-linuxvm_1"
  location              = "westeurope"
  resource_group_name   = azurerm_resource_group.rg-govin.name
  network_interface_ids = [azurerm_network_interface.rg-govin-nic.id]
  size                  = "Standard_DS1_v2"

  os_disk {
    name                 = "rg-govin-linuxvm_1-disk"
    caching              = "ReadWrite"
    storage_account_type = "Prenium_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  computer_name                   = "rg-govin-linux_1"
  admin_username                  = "azureuser"
  disable_password_authentication = true

  admin_ssh_key {
    username   = "azureuser"
    public_key = tls_private_key.rg-govin_ssh.public_key_openssh
  }

  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.rg-govin-storageaccount.primary_blob_endpoint
  }

  tags = {
    environment = "Terraform test"
  }
}
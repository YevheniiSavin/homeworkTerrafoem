# Define provider
provider "azurerm" {
  features {}
}

# Resource Group
resource "azurerm_resource_group" "test_rg" {
  name     = "test-resource-group"
  location = "East US"
}

# Availability Set
resource "azurerm_availability_set" "test_avset" {
  name                         = "test-availability-set"
  location                     = azurerm_resource_group.test_rg.location
  resource_group_name          = azurerm_resource_group.test_rg.name
  managed                      = true
  platform_fault_domain_count  = 2
  platform_update_domain_count = 5
}

# Virtual Network
resource "azurerm_virtual_network" "test_vnet" {
  name                = "test-vnet"
  location            = azurerm_resource_group.test_rg.location
  resource_group_name = azurerm_resource_group.test_rg.name
  address_space       = ["10.1.0.0/16"]
}

# Subnet
resource "azurerm_subnet" "test_subnet" {
  name                 = "test-subnet"
  resource_group_name  = azurerm_resource_group.test_rg.name
  virtual_network_name = azurerm_virtual_network.test_vnet.name
  address_prefixes     = ["10.1.1.0/24"]
}

# Public IP for Load Balancer
resource "azurerm_public_ip" "test_lb_public_ip" {
  name                = "test-lb-public-ip"
  location            = azurerm_resource_group.test_rg.location
  resource_group_name = azurerm_resource_group.test_rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# Load Balancer
resource "azurerm_lb" "test_lb" {
  name                = "test-loadbalancer"
  location            = azurerm_resource_group.test_rg.location
  resource_group_name = azurerm_resource_group.test_rg.name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                 = "TestPublicIPAddress"
    public_ip_address_id = azurerm_public_ip.test_lb_public_ip.id
  }
}

# Backend Address Pool for Load Balancer
resource "azurerm_lb_backend_address_pool" "test_backend_pool" {
  loadbalancer_id = azurerm_lb.test_lb.id
  name            = "test-backend-pool"
}

# Health Probe for Load Balancer
resource "azurerm_lb_probe" "test_probe" {
  loadbalancer_id = azurerm_lb.test_lb.id
  name            = "tcp-probe"
  protocol        = "Tcp"
  port            = 80
  interval_in_seconds = 5
  number_of_probes    = 2
}

# Load Balancer Rule
resource "azurerm_lb_rule" "test_lb_rule" {
  loadbalancer_id                = azurerm_lb.test_lb.id
  name                           = "tcp-rule"
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "TestPublicIPAddress"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.test_backend_pool.id]
  probe_id                       = azurerm_lb_probe.test_probe.id
}

# Network Interface for VMs
resource "azurerm_network_interface" "test_nic" {
  count               = 2
  name                = "test-nic-${count.index}"
  location            = azurerm_resource_group.test_rg.location
  resource_group_name = azurerm_resource_group.test_rg.name

  ip_configuration {
    name                          = "test-internal"
    subnet_id                     = azurerm_subnet.test_subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

# Associate NICs with the Load Balancer Backend Pool
resource "azurerm_network_interface_backend_address_pool_association" "test_lb_nic_association" {
  count                   = 2
  network_interface_id    = azurerm_network_interface.test_nic[count.index].id
  ip_configuration_name   = "test-internal"
  backend_address_pool_id = azurerm_lb_backend_address_pool.test_backend_pool.id
}

# Virtual Machines in the Availability Set
resource "azurerm_linux_virtual_machine" "test_vm" {
  count                 = 2
  name                  = "test-vm-${count.index}"
  resource_group_name   = azurerm_resource_group.test_rg.name
  location              = azurerm_resource_group.test_rg.location
  size                  = "Standard_B1s"
  disable_password_authentication = false
  admin_username        = "testadmin"
  admin_password        = "P@ssw0rd!23"
  availability_set_id   = azurerm_availability_set.test_avset.id
  network_interface_ids = [azurerm_network_interface.test_nic[count.index].id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }
}

# Output the Public IP of the Load Balancer
output "load_balancer_public_ip" {
  value = azurerm_public_ip.test_lb_public_ip.ip_address
}

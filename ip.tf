resource "azurerm_public_ip" "IP" {
  name                = "public_ip"
  location            = "${var.location}"
  resource_group_name = "${var.resource_group_name}"
  allocation_method   = "Dynamic"
  tags                = "${var.tags}"
}

resource "azurerm_public_ip" "IP2" {
  name                = "public_ip2"
  location            = "${var.location}"
  resource_group_name = "${var.resource_group_name}"
  allocation_method   = "Dynamic"
  tags                = "${var.tags}"
}

resource "azurerm_public_ip" "IP3" {
  name                = "public_ip3"
  location            = "${var.location}"
  resource_group_name = "${var.resource_group_name}"
  allocation_method   = "Dynamic"
  tags                = "${var.tags}"
}

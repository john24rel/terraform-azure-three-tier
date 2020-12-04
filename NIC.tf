resource "azurerm_network_interface" "nic1" {
  name                = "nic1"
  location            = "${var.location}"
  resource_group_name = "${var.resource_group_name}"

  ip_configuration {
    name                          = "testconfiguration1"
    subnet_id                     = "${azurerm_subnet.private1.id}"
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = "${azurerm_public_ip.IP.id}"
  }

  tags = "${var.tags}"
}

resource "azurerm_network_interface" "nic2" {
  name                = "nic2"
  location            = "${var.location}"
  resource_group_name = "${var.resource_group_name}"

  ip_configuration {
    name                          = "testconfiguration2"
    subnet_id                     = "${azurerm_subnet.private2.id}"
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = "${azurerm_public_ip.IP2.id}"
  }

  tags = "${var.tags}"
}

resource "azurerm_network_interface" "nic3" {
  name                = "nic3"
  location            = "${var.location}"
  resource_group_name = "${var.resource_group_name}"

  ip_configuration {
    name                          = "testconfiguration3"
    subnet_id                     = "${azurerm_subnet.private3.id}"
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = "${azurerm_public_ip.IP3.id}"
  }

  tags = "${var.tags}"
}

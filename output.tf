output "VM1" {
  value = "${azurerm_virtual_machine.vm1.name} ${azurerm_public_ip.IP.ip_address}"
}

output "VM2" {
  value = "${azurerm_virtual_machine.vm2.name} ${azurerm_public_ip.IP2.ip_address}"
}

output "VM3" {
  value = "${azurerm_virtual_machine.vm3.name} ${azurerm_public_ip.IP3.ip_address}"
}

output "VNET" {
  value = "${azurerm_virtual_network.vnet1.name}"
}

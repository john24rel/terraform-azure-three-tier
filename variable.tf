variable "location" {}
variable "address_space" {}
variable "vnet_name" {}
variable "resource_group_name" {}
variable "security_group_name" {}
variable "vm1_computername" {}
variable "vm2_computername" {}
variable "vm3_computername" {}
variable "environment" {}
variable "private_subnet1_range" {}
variable "private_subnet2_range" {}
variable "private_subnet3_range" {}
variable "vm_size" {}
variable "publisher" {}
variable "sku" {}
variable "offer" {}
variable "os_version" {}
variable "admin_username" {}

variable "tags" {
  type = "map"
}

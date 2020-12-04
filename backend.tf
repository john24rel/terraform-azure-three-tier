# terraform {
#   backend "azurerm" {
#     resource_group_name  = "storage_account"
#     storage_account_name = "oshikoyajohn"
#     container_name       = "tfstate"
#     key                  = "prod.terraform.tfstate"
#     access_key           = "oIAAwgKfI2RHRmo5z7Ldav6L2s0Y+1WeF8mbnFofbWsHr3wifsdJUQCekDR/0oJC4BoOfPGMqfztR7xaTakg0g=="
#   }
# }

terraform {
	backend "s3" {
	bucket = "oshikoya-bucket-terraform"
	key = "path/to/my/azure"
	region = "us-east-2"
    # force_destroy               = true
	}
}
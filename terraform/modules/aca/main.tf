terraform {
  cloud {
    organization = "medkhabt-org"

  }
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.0"
    }
  }
}

provider "azurerm" {
  features {}
}


resource "azurerm_resource_group" "demo_aca" {
  name     = "rg-terraform-demo-aca-${var.enviroment}"
  location = "North Europe"
}

resource "azurerm_virtual_network" "demo-vnet" {
  name = "vnet-aca-demo-${var.enviroment}"
  location = azurerm_resource_group.demo_aca.location
  resource_group_name = azurerm_resource_group.demo_aca.name

  address_space = ["10.0.0.0/26"]

}

resource "azurerm_subnet" "subnet-aca" {
    name = "subnet-aca-${var.enviroment}"
    resource_group_name = azurerm_resource_group.demo_aca.name
    virtual_network_name = azurerm_virtual_network.demo-vnet.name

    address_prefixes = ["10.0.0.0/27"]

    delegation {
      name = "aca-delegation"

      service_delegation {
        name = "Microsoft.App/environments"

        actions = [
          "Microsoft.Network/virtualNetworks/subnets/join/action"
        ]
      }
      
    }
}

resource "azurerm_subnet" "subnet-private-endpoints" {
    name = "subnet-private-endpoints-${var.enviroment}"
    resource_group_name = azurerm_resource_group.demo_aca.name
    virtual_network_name = azurerm_virtual_network.demo-vnet.name

    address_prefixes = ["10.0.0.32/27"]
}

resource "azurerm_log_analytics_workspace" "demo_aca" {
  name                = "law-terraform-demo-aca-${var.enviroment}"
  location            = azurerm_resource_group.demo_aca.location
  resource_group_name = azurerm_resource_group.demo_aca.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

resource "azurerm_container_app_environment" "demo_aca" {
  name                       = "env-terraform-demo-aca-${var.enviroment}"
  location                   = azurerm_resource_group.demo_aca.location
  resource_group_name        = azurerm_resource_group.demo_aca.name
  logs_destination           = "log-analytics"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.demo_aca.id
  infrastructure_subnet_id  = azurerm_subnet.subnet-aca.id

  workload_profile {
    maximum_count         = 0
    minimum_count         = 0
    name                  = "Consumption"
    workload_profile_type = "Consumption"
  }
}

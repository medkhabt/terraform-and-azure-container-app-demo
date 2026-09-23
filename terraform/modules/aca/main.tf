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

// create "spoke" for the demo
resource "azurerm_virtual_network" "demo-vnet" {
  name = "vnet-aca-demo-${var.enviroment}"
  location = azurerm_resource_group.demo_aca.location
  resource_group_name = azurerm_resource_group.demo_aca.name

  address_space = ["10.0.0.0/26"]

}

// subnet delegated to aca env, needs to be at least /27
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

// subnet for private endpoints
resource "azurerm_subnet" "subnet-private-endpoints" {
  name = "subnet-private-endpoints-${var.enviroment}"
  resource_group_name = azurerm_resource_group.demo_aca.name
  virtual_network_name = azurerm_virtual_network.demo-vnet.name

  address_prefixes = ["10.0.0.32/27"]
}

// azure container registry, one acr for all envs 
resource "azurerm_container_registry" "demo-acr" {
  name = "demoacrmedkha"
  resource_group_name = azurerm_resource_group.demo_aca.name
  location = azurerm_resource_group.demo_aca.location

  // use private link
  sku = "Premium"
  admin_enabled = false 

  // TODO disable it after private link. 
  public_network_access_enabled = true

}

resource "azurerm_user_assigned_identity" "demo-aca-identity" {
  name = "identity-aca-demo"
  location = azurerm_resource_group.demo_aca.location
  resource_group_name = azurerm_resource_group.demo_aca.name
}

// assigned the serviceprincipal a role that also assign roles for the resources in resource group
resource "azurerm_role_assignment" "demo-aca-acr-pull" {
  scope = azurerm_container_registry.demo-acr.id
  role_definition_name = "AcrPull"
  principal_id = azurerm_user_assigned_identity.demo-aca-identity.principal_id
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

resource "azurerm_container_app" "demo_aca" {
  name                         = "app-terraform-demo-aca-${var.enviroment}"
  container_app_environment_id = azurerm_container_app_environment.demo_aca.id
  resource_group_name          = azurerm_resource_group.demo_aca.name
  revision_mode                = "Single"
  template {
    min_replicas = 0
    max_replicas = 1
    container {
      name   = "demo"
      image  = "${azurerm_container_registry.demo-acr.login_server}/${var.container_image}"
      cpu    = 0.25
      memory = "0.5Gi"
    }
  }
  ingress {
    external_enabled = true
    target_port      = 80
    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }

  identity {
    type = "UserAssigned"
    identity_ids = [
      azurerm_user_assigned_identity.demo-aca-identity.id
    ]
  }

  registry {
    server = azurerm_container_registry.demo-acr.login_server
    identity = azurerm_user_assigned_identity.demo-aca-identity.id
  }
  depends_on = [azurerm_role_assignment.demo-aca-acr-pull]
}

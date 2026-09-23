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

  public_network_access_enabled = false 

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

// private dns zone for acr private endpoint
resource "azurerm_private_dns_zone" "acr" {
  name                = "privatelink.azurecr.io"
  resource_group_name = azurerm_resource_group.demo_aca.name
}

// link the dns zone to our vnet.
resource "azurerm_private_dns_zone_virtual_network_link" "acr" {
  name                  = "acr-private-dns-link"

  private_dns_zone_id = azurerm_private_dns_zone.acr.id
  virtual_network_id = azurerm_virtual_network.demo-vnet.id

  registration_enabled = false
}

// create private endpoint in private endpoints subnet with private service connectoni
// to the subresource registry of the container registry we provisioned here., and create
// a dns record for the azure acr hostname reference the endpoint ip.
resource "azurerm_private_endpoint" "acr" {
  name                = "pe-${azurerm_container_registry.demo-acr.name}"
  location            = azurerm_resource_group.demo_aca.location
  resource_group_name = azurerm_resource_group.demo_aca.name

  subnet_id = azurerm_subnet.subnet-private-endpoints.id

  private_service_connection {
    name = "psc-${azurerm_container_registry.demo-acr.name}"

    private_connection_resource_id = azurerm_container_registry.demo-acr.id

    subresource_names = [
      "registry"
    ]

    is_manual_connection = false
  }

  private_dns_zone_group {
    name = "acr-private-dns"

    private_dns_zone_ids = [
      azurerm_private_dns_zone.acr.id
    ]
  }
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
      name   = "demo1"
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

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
  name     = "rg-terraform-demo-aca.${var.enviroment}"
  location = "North Europe"
}

resource "azurerm_log_analytics_workspace" "demo_aca" {
  name                = "law-terraform-demo-aca.${var.enviroment}"
  location            = azurerm_resource_group.demo_aca.location
  resource_group_name = azurerm_resource_group.demo_aca.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

resource "azurerm_container_app_environment" "demo_aca" {
  name                       = "env-terraform-demo-aca.${var.enviroment}"
  location                   = azurerm_resource_group.demo_aca.location
  resource_group_name        = azurerm_resource_group.demo_aca.name
  logs_destination           = "log-analytics"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.demo_aca.id
  workload_profile {
    maximum_count         = 0
    minimum_count         = 0
    name                  = "Consumption"
    workload_profile_type = "Consumption"
  }
}

resource "azurerm_container_app" "demo_aca" {
  name                         = "app-terraform-demo-aca.${var.enviroment}"
  container_app_environment_id = azurerm_container_app_environment.demo_aca.id
  resource_group_name          = azurerm_resource_group.demo_aca.name
  revision_mode                = "Single"

  template {
    min_replicas = 0
    max_replicas = 1

    container {
      name   = "demo"
      image  = var.container_image
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
}

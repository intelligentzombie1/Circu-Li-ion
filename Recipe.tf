# Configure Azure provider
provider "azurerm" {
  features {}
}

# Resource Groups
resource "azurerm_resource_group" "rg_east" {
  name     = "iot-rg-east"
  location = "eastus"
}

resource "azurerm_resource_group" "rg_west" {
  name     = "iot-rg-west" 
  location = "westus"
}

# Virtual Networks
resource "azurerm_virtual_network" "vnet_east" {
  name                = "vnet-east"
  resource_group_name = azurerm_resource_group.rg_east.name
  location            = azurerm_resource_group.rg_east.location
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_virtual_network" "vnet_west" {
  name                = "vnet-west"
  resource_group_name = azurerm_resource_group.rg_west.name
  location            = azurerm_resource_group.rg_west.location
  address_space       = ["10.1.0.0/16"]
}

# Subnets
resource "azurerm_subnet" "subnet_east_1" {
  name                 = "subnet-east-1"
  resource_group_name  = azurerm_resource_group.rg_east.name
  virtual_network_name = azurerm_virtual_network.vnet_east.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_subnet" "subnet_east_2" {
  name                 = "subnet-east-2"
  resource_group_name  = azurerm_resource_group.rg_east.name
  virtual_network_name = azurerm_virtual_network.vnet_east.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_subnet" "subnet_east_3" {
  name                 = "subnet-east-3"
  resource_group_name  = azurerm_resource_group.rg_east.name
  virtual_network_name = azurerm_virtual_network.vnet_east.name
  address_prefixes     = ["10.0.3.0/24"]
}


resource "azurerm_subnet" "subnet_west_1" {
  name                 = "subnet-west-1"
  resource_group_name  = azurerm_resource_group.rg_west.name
  virtual_network_name = azurerm_virtual_network.vnet_west.name
  address_prefixes     = ["10.1.1.0/24"]
}

resource "azurerm_subnet" "subnet_west_2" {
  name                 = "subnet-west-2"
  resource_group_name  = azurerm_resource_group.rg_west.name
  virtual_network_name = azurerm_virtual_network.vnet_west.name
  address_prefixes     = ["10.1.2.0/24"]
}

# ExpressRoute Circuit
resource "azurerm_express_route_circuit" "expressroute" {
  name                  = "expressroute-circuit"
  resource_group_name   = azurerm_resource_group.rg_east.name
  location              = azurerm_resource_group.rg_east.location
  service_provider_name = "Equinix"
  peering_location      = "Silicon Valley"
  bandwidth_in_mbps     = 50
  sku {
    tier   = "Standard"
    family = "MeteredData"
  }
}

# IoT Hub
resource "azurerm_iothub" "iothub" {
  name                = "example-iothub"
  resource_group_name = azurerm_resource_group.rg_east.name
  location            = azurerm_resource_group.rg_east.location

  sku {
    name     = "S1"
    capacity = "1"
  }
}

# Event Hub Namespace
resource "azurerm_eventhub_namespace" "eventhub_ns" {
  name                = "example-eventhub-ns"
  location            = azurerm_resource_group.rg_east.location
  resource_group_name = azurerm_resource_group.rg_east.name
  sku                 = "Standard"
  capacity            = 1
}

# Event Hub
resource "azurerm_eventhub" "eventhub" {
  name                = "example-eventhub"
  namespace_name      = azurerm_eventhub_namespace.eventhub_ns.name
  resource_group_name = azurerm_resource_group.rg_east.name
  partition_count     = 2
  message_retention   = 1
}

# Front Door
resource "azurerm_frontdoor" "frontdoor" {
  name                = "example-frontdoor"
  resource_group_name = azurerm_resource_group.rg_east.name

  routing_rule {
    name               = "routing-rule"
    accepted_protocols = ["Http", "Https"]
    patterns_to_match  = ["/*"]
    frontend_endpoints = ["example-frontdoor"]
    forwarding_configuration {
      forwarding_protocol = "MatchRequest"
      backend_pool_name   = "backend"
    }
  }

  backend_pool {
    name = "backend"
    backend {
      host_header = "www.example.com"
      address     = "www.example.com"
      http_port   = 80
      https_port  = 443
    }
  }

  frontend_endpoint {
    name      = "example-frontdoor"
    host_name = "example-frontdoor.azurefd.net"
  }
}

# Log Analytics Workspace for Sentinel
resource "azurerm_log_analytics_workspace" "workspace" {
  name                = "example-workspace"
  location            = azurerm_resource_group.rg_east.location
  resource_group_name = azurerm_resource_group.rg_east.name
  sku                 = "PerGB2018"
}

# Enable Microsoft Sentinel
resource "azurerm_sentinel_log_analytics_workspace_onboarding" "sentinel" {
  workspace_name      = azurerm_log_analytics_workspace.workspace.name
  resource_group_name = azurerm_resource_group.rg_east.name
}

# Storage Account for Function App and Blob
resource "azurerm_storage_account" "storage" {
  name                     = "examplestorage"
  resource_group_name      = azurerm_resource_group.rg_east.name
  location                 = azurerm_resource_group.rg_east.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

# Function App Service Plan
resource "azurerm_service_plan" "asp" {
  name                = "example-asp"
  resource_group_name = azurerm_resource_group.rg_east.name
  location            = azurerm_resource_group.rg_east.location
  os_type            = "Windows"
  sku_name           = "Y1"
}

# Function App
resource "azurerm_windows_function_app" "function" {
  name                       = "example-function"
  resource_group_name        = azurerm_resource_group.rg_east.name
  location                   = azurerm_resource_group.rg_east.location
  storage_account_name       = azurerm_storage_account.storage.name
  storage_account_access_key = azurerm_storage_account.storage.primary_access_key
  service_plan_id           = azurerm_service_plan.asp.id

  site_config {}

  identity {
    type = "SystemAssigned"
  }
}

# Blob Container
resource "azurerm_storage_container" "container" {
  name                  = "data"
  storage_account_name  = azurerm_storage_account.storage.name
  container_access_type = "private"
}

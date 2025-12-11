locals {
  env_suffix = var.environment
}

resource "azurerm_resource_group" "rg" {
  name     = "${var.prefix}-${local.env_suffix}-rg"
  location = var.location
  tags = {
    environment = var.environment
    project     = var.prefix
  }
}

resource "azurerm_container_registry" "acr" {
  name                = "${replace(var.prefix, "-", "")}${local.env_suffix}acr"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "Basic"
  # admin_enabled should be false in production for security. Use managed identities or service principals for automation.
  admin_enabled       = false
  tags = {
    environment = var.environment
    project     = var.prefix
  }
}

resource "azurerm_kubernetes_cluster" "aks" {
  name                = "${var.prefix}-${local.env_suffix}-aks"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  dns_prefix          = "${var.prefix}-${local.env_suffix}"

  default_node_pool {
    name       = "system"
    node_count = var.aks_node_count
    vm_size    = var.aks_node_size
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin = "azure"
  }

  role_based_access_control_enabled = true
  tags = {
    environment = var.environment
    project     = var.prefix
  }
}

data "azurerm_kubernetes_service_versions" "current" {
  location        = var.resource_group_location
  include_preview = false
}

resource "azurerm_kubernetes_cluster" "main" {
  name                            = "${var.prefix}-aks"
  location                        = var.resource_group_location
  resource_group_name             = var.resource_group_name
  dns_prefix                      = var.prefix
  node_resource_group             = "${var.prefix}-worker-rg"
  kubernetes_version              = var.kubernetes_version != null ? var.kubernetes_version : data.azurerm_kubernetes_service_versions.current.latest_version
  api_server_authorized_ip_ranges = var.authorized_ip_ranges

  default_node_pool {
    name                 = "default"
    node_count           = var.node_count
    vm_size              = var.vm_size
    vnet_subnet_id       = var.vnet_subnet_id
    orchestrator_version = var.kubernetes_version != null ? var.kubernetes_version : data.azurerm_kubernetes_service_versions.current.latest_version
    tags                 = var.tags
    enable_auto_scaling  = var.enable_auto_scaling
    min_count            = var.min_count
    max_count            = var.max_count
    availability_zones   = var.availability_zones
  }

  addon_profile {
    azure_policy {
      enabled = true
    }
    kube_dashboard {
      enabled = false
    }
    oms_agent {
      enabled                    = true
      log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
    }
  }

  identity {
    type = "SystemAssigned"
  }

  role_based_access_control {
    enabled = true
    azure_active_directory {
      managed                = true
      admin_group_object_ids = var.admin_group_object_ids
    }
  }

  network_profile {
    network_plugin = "azure"
    network_policy = "azure"
  }

  tags = var.tags
}

resource "azurerm_kubernetes_cluster_node_pool" "name" {
  kubernetes_cluster_id = azurerm_kubernetes_cluster.main.id
  for_each              = var.additional_node_pools
  name                  = each.key
  node_count            = each.value.node_count
  vm_size               = each.value.vm_size
  vnet_subnet_id        = each.value.vnet_subnet_id
  orchestrator_version  = each.value.kubernetes_version != null ? each.value.kubernetes_version : data.azurerm_kubernetes_service_versions.current.latest_version
  availability_zones    = each.value.availability_zones
  enable_auto_scaling   = each.value.enable_auto_scaling
  min_count             = each.value.min_count
  max_count             = each.value.max_count
}

resource "azurerm_log_analytics_workspace" "main" {
  name                = "${var.prefix}-law"
  resource_group_name = var.resource_group_name
  location            = var.resource_group_location
  sku                 = var.log_analytics_workspace_sku
  retention_in_days   = var.log_retention_in_days

  tags = var.tags
}

provider "kubernetes" {
  load_config_file       = false
  host                   = azurerm_kubernetes_cluster.main.kube_admin_config.0.host
  username               = azurerm_kubernetes_cluster.main.kube_admin_config.0.username
  password               = azurerm_kubernetes_cluster.main.kube_admin_config.0.password
  client_certificate     = base64decode(azurerm_kubernetes_cluster.main.kube_admin_config.0.client_certificate)
  client_key             = base64decode(azurerm_kubernetes_cluster.main.kube_admin_config.0.client_key)
  cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.main.kube_admin_config.0.cluster_ca_certificate)
}

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.15.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "=3.1.0"
    }
  }
  backend "azurerm" {

  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }

  subscription_id = var.subscription_id
}

locals {
  func_name = "func${random_string.unique.result}"
  loc_for_naming = lower(replace(var.location, " ", ""))
  gh_repo = replace(var.gh_repo, "implodingduck/", "")
  tags = {
    "managed_by" = "terraform"
    "repo"       = local.gh_repo
  }
}

resource "random_string" "unique" {
  length  = 8
  special = false
  upper   = false
}


data "azurerm_client_config" "current" {}

data "azurerm_log_analytics_workspace" "default" {
  name                = "DefaultWorkspace-${data.azurerm_client_config.current.subscription_id}-EUS"
  resource_group_name = "DefaultResourceGroup-EUS"
} 

data "azurerm_network_security_group" "basic" {
    name                = "basic"
    resource_group_name = "rg-network-eastus"
}

resource "azurerm_resource_group" "rg" {
  name     = "rg-${local.gh_repo}-${random_string.unique.result}-${local.loc_for_naming}"
  location = var.location
  tags = local.tags
}

resource "azurerm_application_insights" "app" {
  name                = "${local.gh_repo}-${random_string.unique.result}-insights"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  application_type    = "other"
  workspace_id        = data.azurerm_log_analytics_workspace.default.id
}


resource "azurerm_service_plan" "asp" {
  name                = "asp-${local.gh_repo}-${random_string.unique.result}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  os_type             = "Linux"
  sku_name            = "B1"
}

resource "azurerm_linux_web_app" "app" {
  name                = "${local.gh_repo}${random_string.unique.result}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_service_plan.asp.location
  service_plan_id     = azurerm_service_plan.asp.id

  app_settings = {
    APPINSIGHTS_INSTRUMENTATIONKEY = azurerm_application_insights.app.instrumentation_key
    SCM_DO_BUILD_DURING_DEPLOYMENT = true
    DB_HOST                        = azurerm_mssql_server.db.fully_qualified_domain_name 
    DB_NAME                        = azurerm_mssql_database.db.name
  }
  
  site_config {
    application_stack {
      python_version = 3.9
    }
  }
  logs {
    application_logs {
      file_system_level = "Verbose"
    }
    http_logs{
      file_system {
        retention_in_mb = 35
        retention_in_days = 0
      }
    }
  }

  identity{
    type = "SystemAssigned"
  }
}

resource "azurerm_mssql_server" "db" {
  name                         = "${local.gh_repo}${random_string.unique.result}-server"
  resource_group_name          = azurerm_resource_group.rg.name
  location                     = azurerm_resource_group.rg.location
  version                      = "12.0"
  
  minimum_tls_version          = "1.2"
  azuread_administrator {
    login_username              = var.az_db_username
    object_id                   = var.az_db_oid
    azuread_authentication_only = true
  }
  tags = local.tags
}

resource "azurerm_mssql_database" "db" {
  name                        = "${local.gh_repo}${random_string.unique.result}db"
  server_id                   = azurerm_mssql_server.db.id
  max_size_gb                 = 40
  auto_pause_delay_in_minutes = -1
  min_capacity                = 1
  sku_name                    = "GP_S_Gen5_1"
  tags = local.tags
  short_term_retention_policy {
    retention_days = 7
  }
}

resource "azurerm_mssql_firewall_rule" "azureservices" {
  name             = "azureservices"
  server_id        = azurerm_mssql_server.db.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

resource "azurerm_role_assignment" "app_to_sql" {
  scope                = azurerm_mssql_server.db.id
  role_definition_name = "SQL DB Contributor"
  principal_id         = azurerm_linux_web_app.app.identity.0.principal_id
}
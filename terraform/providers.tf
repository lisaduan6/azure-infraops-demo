terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }

  # Remote backend for storing Terraform state securely in Azure Storage.
  # Ensure access is restricted using Azure RBAC and secrets are managed securely.
  backend "azurerm" {
    resource_group_name   = "infraops-tfstate-rg"
    storage_account_name  = "infraopstfstateacctdemo"
    container_name        = "tfstate"
    key                   = "infraops-demo.terraform.tfstate"
  }
}

provider "azurerm" {
  features {}

  subscription_id = "f2fab6a2-9578-40b1-bdcb-6dd802e29875"
  tenant_id       = "6c425ff2-6865-42df-a4db-8e6af634813d"
}

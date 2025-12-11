variable "prefix" {
  description = "Base name prefix for all resources. Should be unique per project."
  type        = string
  default     = "infraops-demo"
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "swedencentral"
}


variable "environment" {
  description = "Environment name (dev|uat|prod). Used for resource naming and tagging."
  type        = string
  default     = "dev"
}

variable "aks_node_count" {
  description = "Number of nodes in the default AKS node pool. Adjust for workload needs."
  type        = number
  default     = 1
}

variable "aks_node_size" {
  description = "VM size for AKS nodes. Choose based on workload and cost."
  type        = string
  default     = "Standard_B2s"
}

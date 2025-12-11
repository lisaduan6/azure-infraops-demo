# Terraform - Azure AKS + ACR + Resource Group

这里是 AKS + ACR + Resource Group 的 IaC 配置，支持 dev / uat / prod 多环境。

## Backend（远程 state）

在 `providers.tf` 中我配置了一个 **示例** Azure Storage backend：

```hcl
backend "azurerm" {
  resource_group_name   = "infraops-tfstate-rg"
  storage_account_name  = "infraopstfstateacct"
  container_name        = "tfstate"
  key                   = "infraops-demo.terraform.tfstate"
}
```

实际使用时需要你：

1. 先创建保存 state 的 RG + Storage Account + Container  
2. 把上面的名称改成你自己的  
3. 再执行 `terraform init -reconfigure`

这样所有环境共享同一个 remote backend，但通过 workspace / environment 变量实现隔离。

## 多环境（environment + workspace）

通过变量：

```hcl
variable "environment" {
  description = "Environment name (dev|uat|prod)"
}
```

配合 workspace，可以这样用：

```bash
cd terraform

terraform init

# 为 dev 创建 workspace
terraform workspace new dev || terraform workspace select dev
terraform apply -auto-approve -var "environment=dev"

# 为 uat
terraform workspace new uat || terraform workspace select uat
terraform apply -auto-approve -var "environment=uat"

# 为 prod
terraform workspace new prod || terraform workspace select prod
terraform plan   -var "environment=prod"
terraform apply  -var "environment=prod"
```

也可以不用 workspace，直接依靠 `environment` 变量和不同的 state key / 不同后端容器来做隔离，取决于你的团队偏好。

## 输出

Terraform 输出：

- `resource_group_name`
- `aks_name`
- `acr_login_server`
- `acr_admin_username`
- `acr_admin_password`（敏感）

这些会被：

- Ansible playbook 使用（如生成 kubeconfig）
- Azure DevOps Pipeline 使用（AKS / ACR 相关变量）

# Azure DevOps / InfraOps Demo 项目（AKS + ACR + Terraform + Ansible）

用于 DevOps / SRE / Infra 面试演示的完整 Demo，包含：

- Terraform：AKS + ACR + Resource Group（多环境 dev / uat / prod，远程 state + workspace 示例）
- Ansible：自动化 Terraform、kubeconfig、部署 K8s、滚动更新镜像
- Azure DevOps Pipelines：CI（Build+Lint+Test） / CD（dev / uat / prod，多阶段，prod 有审批）
- 监控最小实现：Prometheus + Grafana（K8s 部署）
- 示例应用：Flask + `/metrics`（Prometheus 可抓取）
- K8s manifests：Deployment / Service / HPA

目录结构：

```text
terraform/              # AKS + ACR + RG IaC（含 remote backend + workspace 用法）
ansible/
  inventory/
  playbooks/            # 自动化 Terraform & kubeconfig & 部署 & 更新
azure-pipelines-build.yml   # CI：lint + test + build + push ACR
azure-pipelines-deploy.yml  # CD：dev/uat 自动，prod 审批后部署
app/                    # Flask 示例应用 + Dockerfile
k8s/                    # 应用 K8s manifests
monitoring/             # Prometheus & Grafana
tests/                  # pytest 简单冒烟测试
README_AZURE.md         # 本说明
```

---

## 1. 前置准备

本地需要：

- Terraform >= 1.5
- Azure CLI (`az`)
- kubectl
- Ansible >= 2.15
- Docker（本地调试镜像可选）
- Azure 订阅（能创建 AKS & ACR）
- Azure DevOps 项目（用来跑 CI/CD）

登录 Azure：

```bash
az login
az account set --subscription "<你的 Subscription ID>"
```

---

## 2. Terraform：远程 state + 多环境

### 2.1 远程 state（示例）

`terraform/providers.tf` 中配置了一个 Azurerm backend 示例：

```hcl
backend "azurerm" {
  resource_group_name   = "infraops-tfstate-rg"
  storage_account_name  = "infraopstfstateacct"
  container_name        = "tfstate"
  key                   = "infraops-demo.terraform.tfstate"
}
```

实际使用时你需要：

1. 在 Azure 中先创建：
   - 一个 Resource Group（例如 `infraops-tfstate-rg`）
   - 一个 Storage Account（例如 `infraopstfstateacct`）
   - 一个 Blob Container（例如 `tfstate`）
2. 修改 backend 配置为你自己的名称
3. 执行：

```bash
cd terraform
terraform init -reconfigure
```

### 2.2 Workspace + environment

通过 `var.environment` + `terraform workspace` 实现环境隔离：

```bash
cd terraform
terraform init

# dev
terraform workspace new dev || terraform workspace select dev
terraform apply -auto-approve -var "environment=dev"

# uat
terraform workspace new uat || terraform workspace select uat
terraform apply -auto-approve -var "environment=uat"

# prod（建议先 plan）
terraform workspace new prod || terraform workspace select prod
terraform plan  -var "environment=prod"
terraform apply -var "environment=prod"
```

Terraform 输出包含：

- `resource_group_name`
- `aks_name`
- `acr_login_server`（给 CI/CD 用）
- `acr_admin_username`
- `acr_admin_password`（敏感，只在 Demo 或 POC 场景使用）

---

## 3. Ansible：自动化 Infra + 部署

### 3.1 inventory / 配置

`ansible/inventory/hosts`：

```ini
[dev]
localhost ansible_connection=local environment=dev

[uat]
localhost ansible_connection=local environment=uat

[prod]
localhost ansible_connection=local environment=prod
```

`ansible/ansible.cfg` 里配置了默认 inventory 和基础选项。

### 3.2 使用 Ansible 执行 Terraform

```bash
cd ansible

# dev
ansible-playbook playbooks/terraform_apply.yml -e target_env=dev

# uat
ansible-playbook playbooks/terraform_apply.yml -e target_env=uat

# prod
ansible-playbook playbooks/terraform_apply.yml -e target_env=prod
```

### 3.3 获取 AKS kubeconfig

```bash
ansible-playbook playbooks/generate_kubeconfig.yml -e target_env=dev
```

执行完后 `~/.kube/config` 会包含对应 AKS 集群的上下文，可以直接：

```bash
kubectl get nodes
```

### 3.4 部署应用 + 监控

```bash
ansible-playbook playbooks/deploy_to_aks.yml -e target_env=dev
```

Playbook 会：

1. 检查 kubeconfig
2. 创建 `app` Namespace
3. 部署 `k8s/` 下应用 Deployment / Service / HPA
4. 部署 `monitoring/` 下的 Prometheus + Grafana

---

## 4. Azure DevOps：CI Pipeline（lint + test + build + push）

文件：`azure-pipelines-build.yml`

职责：

- 对应用代码做 lint + 单元测试
- 构建 Docker 镜像
- 推送到 ACR
- 输出镜像完整名字作为 artifact（`image-info/image.txt`）

主要步骤：

1. 使用 `UsePythonVersion@0` 选择 Python 3.11
2. 安装依赖：

   ```bash
   pip install -r app/requirements.txt
   pip install flake8 pytest
   ```

3. Lint：

   ```bash
   flake8 app
   ```

4. 测试（`tests/test_smoke.py`）：

   ```bash
   pytest -q
   ```

5. Build + push：

   ```bash
   docker build -t <ACR_LOGIN_SERVER>/infraops-demo-app:<git_sha> -f app/Dockerfile app
   docker push ...
   ```

6. 将最终镜像名写入 `image.txt` 并通过 `PublishBuildArtifacts@1` 发布

在 Azure DevOps 中：

- 新建 Pipeline 指向 `azure-pipelines-build.yml`
- 设置变量：
  - `ACR_NAME`
  - （如需）服务连接为 `azure-sp`

---

## 5. Azure DevOps：CD Pipeline（dev/uat 自动，prod 需审批）

文件：`azure-pipelines-deploy.yml`

职责：

- 从 CI Pipeline 获取 `image-info` artifact
- 依次部署到：
  - dev（自动）
  - uat（自动）
  - prod（需审批）

### 5.1 CI/CD 资源关联

顶部 `resources.pipelines`：

```yaml
resources:
  pipelines:
    - pipeline: ciPipeline
      source: "infraops-ci"
      trigger:
        branches:
          include:
            - main
```

`source` 是 CI Pipeline 的名称。CI 成功后会触发 CD，使用最新 artifact。

### 5.2 多环境 AKS 部署逻辑

每个 Stage（Dev/UAT/Prod）逻辑基本一致：

1. 下载 artifact：
   ```bash
   IMAGE_FULL_NAME=$(cat image.txt)
   ```

2. 用 `AzureCLI@2` 获取对应环境 AKS 凭据：
   ```bash
   az aks get-credentials --resource-group <RG> --name <AKS> --overwrite-existing
   ```

3. `kubectl apply -f k8s/` 保证 manifests 收敛到期望状态
4. `kubectl set image` 做滚动更新：
   ```bash
   kubectl set image deployment/app-deployment      app-container=$IMAGE_FULL_NAME -n app
   kubectl rollout status deployment/app-deployment -n app
   ```

### 5.3 Prod 审批机制

Prod Stage：

```yaml
- stage: Deploy_Prod
  environment: "prod"
  ...
```

在 Azure DevOps 中：

1. 打开 `Pipelines -> Environments`
2. 创建一个名为 `prod` 的 Environment
3. 配置 `Approvals and checks`：
   - 添加 `Approvals`
   - 指定审批人（Tech Lead / 你的另一个账号）

之后每次流水线跑到 Prod Stage 时都会停在审批环节，审批通过后才会真正部署到生产集群。

---

## 6. 发布策略与回滚

### 6.1 发布策略（Release Strategy）

- **dev**：自动部署，用于开发自测与联调
- **uat**：自动部署，用于业务验收测试
- **prod**：需审批的受控发布，审批记录可审计

整条链路：

1. 开发 push 到 `main`
2. CI：
   - lint + test 不通过 → 阻止构建和后续所有部署
   - 通过 → build + push 镜像，生成 `image-info` artifact
3. CD：
   - 自动部署 dev & uat
   - Prod 需要 Owner / Reviewer 审批之后才执行

### 6.2 回滚策略（简单可讲的版本）

若新版本在某环境出现问题，你可以：

1. 快速回滚到上一版镜像：

   ```bash
   kubectl rollout undo deployment/app-deployment -n app
   ```

2. 或者在 CD Pipeline 中：
   - 加一个手动 job / 脚本使用 `kubectl rollout undo`
   - 或通过重新部署上一个 CI 运行生成的镜像（历史 artifact）

面试时可以直接说：

> “我在 Kubernetes 层依赖 Deployment 的滚动发布和 `rollout undo` 做快速回滚；再配合 Azure DevOps 的 artifact 和 CI 运行历史，可以根据需要回滚到任意一个稳定版本的镜像。”

---

## 7. 示例应用与监控

- Flask 应用：
  - `/`：返回简单文本
  - `/healthz`：健康检查
  - `/metrics`：Prometheus 指标（使用 `prometheus_client`）

- Deployment 中注解：
  ```yaml
  prometheus.io/scrape: "true"
  prometheus.io/path: "/metrics"
  prometheus.io/port: "5000"
  ```

- Prometheus + Grafana：
  - `monitoring/` 目录内包含 Deployment + Service + ConfigMap
  - 通过 Ansible 或手动 `kubectl apply -f monitoring`

访问方式（本地）：

```bash
kubectl port-forward svc/prometheus -n monitoring 9090:9090
kubectl port-forward svc/grafana -n monitoring 3000:3000
```

---

## 8. 面试演示建议流程

1. 快速过一遍项目结构（Terraform / Ansible / Pipelines / App / Monitoring）
2. 说明 Terraform 的 remote backend + workspace 做多环境管理
3. 展示 Ansible playbook 如何：
   - 跑 Terraform
   - 拿 kubeconfig
   - 一键部署 app + 监控
4. 打开 Azure DevOps：
   - 展示 `azure-pipelines-build.yml`：lint + test + build + push
   - 展示 `azure-pipelines-deploy.yml`：dev/uat/prod 多阶段 + prod 审批
5. 改一行 Flask 返回文本 → push
6. 让 CI/CD 跑起来：
   - 看 dev / uat 自动部署
   - 手动审批 prod，再看滚动更新
7. 最后展示 Prometheus/Grafana 上的指标变化 + explain 回滚方案

这样一整套演示下来，基本所有 JD 里的点都会被你自然覆盖到。

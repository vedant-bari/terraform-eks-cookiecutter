
# 🚀 Terraform EKS Cluster Module

This repository provisions a production-grade **Amazon EKS Cluster** using the official `terraform-aws-modules/eks/aws` module. It is designed to support scalable workloads with separate system and application node groups, IRSA, managed add-ons, and secure networking.

---

## 📌 Overview

This Terraform configuration creates:

* Amazon EKS Cluster (Kubernetes managed control plane)
* VPC-integrated networking with private subnets
* IAM-based authentication (pre-created roles)
* IRSA (IAM Roles for Service Accounts)
* Managed node groups:

  * System node group (critical workloads)
  * Application node group (business workloads)
* AWS managed EKS add-ons (CoreDNS, kube-proxy, VPC CNI, EBS CSI)
* Secure cluster endpoint configuration
* Encryption for Kubernetes secrets
* Cluster logging support

---

## 🏗️ Architecture

### Cluster Design

* **Control Plane**: AWS Managed EKS
* **Networking**: Existing VPC with private subnets
* **Node Groups**:

  * `system` → runs critical system components
  * `application` → runs user workloads

### High-Level Flow

```
VPC (Private Subnets)
        │
        ▼
   EKS Control Plane
        │
 ┌──────┴─────────┐
 ▼                ▼
System Nodes   App Nodes
(Critical)     (Workloads)
```

---

## 📦 Requirements

| Tool         | Version                         |
| ------------ | ------------------------------- |
| Terraform    | >= 1.6.0                        |
| AWS Provider | >= 6.0                          |
| AWS CLI      | Latest                          |
| kubectl      | Compatible with cluster version |

---

## ⚙️ Inputs (Variables)

| Variable                    | Description                        |
| --------------------------- | ---------------------------------- |
| `cluster_name`              | Name of the EKS cluster            |
| `kubernetes_version`        | Kubernetes version (e.g., 1.29)    |
| `vpc_id`                    | VPC where cluster will be deployed |
| `private_subnet_ids`        | Private subnets for nodes          |
| `cluster_role_arn`          | IAM role for EKS control plane     |
| `node_role_arn`             | IAM role for worker nodes          |
| `endpoint_public_access`    | Enable public API endpoint         |
| `endpoint_private_access`   | Enable private API endpoint        |
| `public_access_cidrs`       | Allowed CIDRs for public access    |
| `enabled_cluster_log_types` | Cluster logging types              |
| `tags`                      | Resource tagging                   |
| `environment`               | Environment name (dev/stage/prod)  |

---

## 🧱 Node Groups

### 🔧 System Node Group

Used for critical Kubernetes components.

* AMI: Bottlerocket
* Tainted with:

  ```
  CriticalAddonsOnly=true:NoSchedule
  ```
* Label: `workload=system`

### 🧪 Application Node Group

Used for application workloads.

* AMI: Bottlerocket
* Label: `workload=application`

---

## 🔐 Security Features

* IAM roles externally managed (no auto creation)
* IRSA enabled for pod-level IAM access
* Private subnet deployment for worker nodes
* Encryption enabled for Kubernetes secrets
* Security groups auto-managed by module
* Endpoint access control (public/private)

---

## 🔌 EKS Add-ons

This module manages AWS-supported add-ons:

* CoreDNS
* kube-proxy
* VPC CNI
* AWS EBS CSI Driver

Conflict resolution strategy:

```
resolve_conflicts_on_create = OVERWRITE
resolve_conflicts_on_update = OVERWRITE
```

---

## 🚀 Usage

### 1. Initialize Terraform

```bash
terraform init
```

### 2. Validate configuration

```bash
terraform validate
```

### 3. Plan deployment

```bash
terraform plan
```

### 4. Apply infrastructure

```bash
terraform apply
```

---

## 🔑 Post Deployment

Configure kubeconfig:

```bash
aws eks update-kubeconfig \
  --region <region> \
  --name <cluster_name>
```

Verify nodes:

```bash
kubectl get nodes
```

---

## 📊 Tags Strategy

All resources are tagged with:

```hcl
Environment = var.environment
ManagedBy   = "Terraform"
Terraform   = "true"
```

---

## 🧩 Key Features

* Modular and reusable EKS setup
* Production-ready node group separation
* Bottlerocket AMI for security & performance
* Fully IAM-integrated architecture
* Scalable and multi-environment friendly

---

## 🛠️ Best Practices Followed

* No hardcoded values (fully variable-driven)
* IAM roles managed outside module (least privilege control)
* Separate system and workload node pools
* Secure endpoint configuration support
* Standardized tagging strategy
* AWS managed add-ons instead of self-managed components

---

## 📈 Future Enhancements

* Add autoscaling policies (Karpenter support)
* Enable cluster autoscaler integration
* Add observability stack (Prometheus + Grafana)
* Add GitOps integration (ArgoCD / FluxCD)
* Enable logging pipeline (CloudWatch → OpenSearch)

---

## 📜 License

This project is intended for internal DevOps/Platform engineering use.

---

If you want, I can also generate:

* `variables.tf`
* `outputs.tf`
* folder structure for multi-environment setup (dev/stage/prod)
* or a full **cookiecutter-style EKS module scaffold**
b
# Terragrunt with Terraform 

## 1. Introduction

When building infrastructure using Terraform, teams often start with a few resources and a single environment. Over time, infrastructure grows to include multiple environments such as **Development**, **QA**, **UAT**, and **Production**.

Managing this complexity using only Terraform becomes difficult due to:

* Code duplication
* Dependency handling challenges
* Backend configuration repetition
* State management complexities

**Terragrunt** is a thin wrapper around Terraform that helps solve these operational problems while still using Terraform as the underlying Infrastructure as Code (IaC) engine.

---

## 2. Why Not Use Terraform Only?

Terraform is excellent at provisioning infrastructure, but when managing large-scale environments, teams commonly face several operational challenges.

### Problem 1: Code Duplication

A typical Terraform setup might look like this:

```text
dev/
├── vpc
├── eks
└── iam

qa/
├── vpc
├── eks
└── iam

prod/
├── vpc
├── eks
└── iam
```

Each environment requires similar code with only small differences.

Example:

```hcl
backend "s3" {
  bucket = "terraform-state-dev"
  key    = "vpc/terraform.tfstate"
  region = "ap-south-1"
}
```

The same configuration gets copied for QA and Production.

#### Challenges

* Repetitive code
* Difficult maintenance
* Higher chance of configuration mistakes
* Updates must be performed in multiple places

---

### Problem 2: Backend Configuration Repetition

Every Terraform module requires backend configuration.

Example:

```hcl
terraform {
  backend "s3" {
    bucket = "company-tf-state"
    key    = "dev/vpc.tfstate"
    region = "ap-south-1"
  }
}
```

Managing this manually across dozens of modules becomes tedious.

---

### Problem 3: Dependency Management

Resources often depend on each other.

Example:

```text
VPC
 ↓
IAM Roles
 ↓
EKS Cluster
 ↓
Add-ons
 ↓
Applications
```

Terraform does not naturally understand dependencies across separate folders.

---

### Problem 4: Multi-Environment Complexity

Managing multiple environments such as:

* Development
* QA
* Staging
* Production

requires separate variables, remote state references, and execution procedures.

Terraform alone provides no standard approach for handling this complexity.

---

## 3. What is Terragrunt?

Terragrunt is an open-source tool developed by **Gruntwork**.

It wraps Terraform and provides features that simplify the management of Terraform at scale.

> **Important:** Terragrunt does **not** replace Terraform.

Instead, Terragrunt orchestrates and manages Terraform more efficiently.

The relationship can be represented as:

```text
Terragrunt
     ↓
Terraform
     ↓
Cloud Provider (AWS / Azure / GCP)
```

---

## 4. Why We Use Terragrunt

We use Terragrunt primarily to reduce operational overhead.

### a. DRY Principle (Don't Repeat Yourself)

Terragrunt allows shared configuration.

Example:

#### Root Configuration

```hcl
remote_state {
  backend = "s3"

  config = {
    bucket = "company-tf-state"
    region = "ap-south-1"
  }
}
```

Child modules inherit this configuration.

#### Benefits

* One place to update configurations
* Less duplication
* Easier maintenance

---

### b. Execute Multiple Modules Together

#### Using Terraform

```bash
cd vpc
terraform apply

cd ../iam
terraform apply

cd ../eks
terraform apply
```

#### Using Terragrunt

```bash
terragrunt run-all apply
```

#### Benefits

* Faster execution
* Simpler CI/CD pipelines
* Better user experience

---

## 5. Terraform vs Terragrunt

| Feature                            | Terraform Only | Terraform + Terragrunt |
| ---------------------------------- | -------------- | ---------------------- |
| DRY Configuration                  | Limited        | ✓                      |
| Backend Reuse                      | Manual         | ✓                      |
| Dependency Handling Across Modules | Manual         | ✓                      |
| Multi-Environment Management       | Manual         | ✓                      |
| Shared Variables                   | Limited        | ✓                      |
| Run Multiple Modules Together      | No             | ✓                      |
| Reduced Code Duplication           | Limited        | ✓                      |
| Easier CI/CD Integration           | Moderate       | High                   |

---

## 6. Advantages of Terragrunt

Using Terragrunt provides several benefits.

### Operational Benefits

* Reduces repetitive Terraform code
* Simplifies backend management
* Standardizes project structure
* Minimizes configuration drift
* Improves maintainability

### Team Benefits

* Faster onboarding for new engineers
* Consistent implementation patterns
* Reduced chances of deployment mistakes
* Easier collaboration across teams

---

## 7. When Should We Use Terragrunt?

### Use Terragrunt When:

* You manage multiple environments (Dev, QA, Prod)
* Infrastructure consists of many modules
* Teams require standardized patterns
* Backend configuration needs centralization
* CI/CD pipelines deploy multiple components
* Infrastructure is expected to scale over time

### Use Terraform Only When:

* Infrastructure is small
* There are very few modules
* Only one environment exists
* Simplicity is preferred over orchestration features

---

## 8. Conclusion

Terraform is responsible for creating and managing infrastructure.

Terragrunt is responsible for making Terraform easier to operate at scale.

A simple way to think about it is:

> **Terraform builds the infrastructure. Terragrunt organizes how Terraform is used.**

For enterprise environments involving **EKS**, **VPCs**, **IAM roles**, shared modules, and multiple environments, Terragrunt helps enforce consistency, reduce duplication, and simplify deployments, making infrastructure management more efficient and maintainable.

---

## Key Takeaway

```text
Terraform = Infrastructure Provisioning

Terragrunt = Terraform Orchestration and Standardization
```

Use Terraform to build resources.

Use Terragrunt when your Terraform implementation grows and requires consistency, scalability, and easier operations.

data "google_client_config" "default" {}


resource "kubernetes_namespace_v1" "jenkins" {
  metadata {
    name = "jenkins"
  }
}

# 1. Create a dedicated Google Service Account for Jenkins CI/CD agents
resource "google_service_account" "jenkins_gsa" {
  project      = var.project_id
  account_id   = "jenkins-agent-gsa"
  display_name = "GSA for Jenkins CI/CD Agents"
}

# 2. Grant Jenkins GSA project-wide writer access to Google Artifact Registry
resource "google_project_iam_member" "jenkins_gar_writer" {
  project = var.project_id
  role    = "roles/artifactregistry.writer"
  member  = "serviceAccount:${google_service_account.jenkins_gsa.email}"
}

# 3. Bind Workload Identity for the Jenkins Agent Kubernetes Service Account
resource "google_service_account_iam_member" "jenkins_workload_identity" {
  service_account_id = google_service_account.jenkins_gsa.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[jenkins/jenkins-agent]"
}

# 4. Kubernetes Service Account for Jenkins Agents annotated with the GSA
resource "kubernetes_service_account_v1" "jenkins_agent_sa" {
  metadata {
    name      = "jenkins-agent"
    namespace = kubernetes_namespace_v1.jenkins.metadata[0].name
    annotations = {
      "iam.gke.io/gcp-service-account" = google_service_account.jenkins_gsa.email
    }
  }
}

# 5. RBAC Role: Allow Jenkins to read secrets in its own namespace
resource "kubernetes_role_v1" "jenkins_secret_reader" {
  metadata {
    name      = "jenkins-secret-reader"
    namespace = kubernetes_namespace_v1.jenkins.metadata[0].name
  }

  rule {
    api_groups     = [""]
    resources      = ["secrets"]
    verbs          = ["get", "list", "watch"]
  }
}

# 6. RBAC RoleBinding: Bind the Role to the Jenkins controller ServiceAccount
resource "kubernetes_role_binding_v1" "jenkins_secret_reader_binding" {
  metadata {
    name      = "jenkins-secret-reader-binding"
    namespace = kubernetes_namespace_v1.jenkins.metadata[0].name
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role_v1.jenkins_secret_reader.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = "jenkins" # Standard service account name used by the official Jenkins Helm chart
    namespace = kubernetes_namespace_v1.jenkins.metadata[0].name
  }
}

# 7. Jenkins Helm Release Deployment
resource "helm_release" "jenkins" {
  name             = "jenkins"
  repository       = "https://charts.jenkins.io"
  chart            = "jenkins"
  namespace        = kubernetes_namespace_v1.jenkins.metadata[0].name
  create_namespace = true
  version          = "5.4.1"
  timeout          = 1200

  values = [
    templatefile(var.yaml_path, {
      cluster_endpoint       = var.cluster_endpoint
      cluster_ca_certificate = var.cluster_ca_certificate
    })
  ]

  depends_on = [
    kubernetes_role_binding_v1.jenkins_secret_reader_binding,
    kubernetes_service_account_v1.jenkins_agent_sa
  ]
}
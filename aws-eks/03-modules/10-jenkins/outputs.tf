output "namespace" {
  description = "Jenkins namespace."
  value       = kubernetes_namespace_v1.jenkins.metadata[0].name
}

output "agent_service_account" {
  description = "Service account the agent pods run as."
  value       = kubernetes_service_account_v1.jenkins_agent_sa.metadata[0].name
}

output "agent_role_arn" {
  description = "Pod Identity role of the agents (ECR push to <namespace>/*)."
  value       = aws_iam_role.jenkins_agent.arn
}

output "jenkins_internal_url" {
  description = "In-cluster Jenkins URL, used by the job sync in 08-applications."
  value       = "http://jenkins.${kubernetes_namespace_v1.jenkins.metadata[0].name}.svc.cluster.local:8080"
}

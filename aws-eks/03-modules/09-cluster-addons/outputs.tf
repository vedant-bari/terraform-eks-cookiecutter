output "lb_controller_role_arn" {
  description = "Pod Identity role of the AWS Load Balancer Controller."
  value       = module.lb_controller_pod_identity.iam_role_arn
}

output "cluster_autoscaler_role_arn" {
  description = "Pod Identity role of the Cluster Autoscaler."
  value       = module.cluster_autoscaler_pod_identity.iam_role_arn
}

output "ingress_class_name" {
  description = "IngressClass created by the LB controller; apps and Jenkins use ingressClassName: alb."
  value       = "alb"
}

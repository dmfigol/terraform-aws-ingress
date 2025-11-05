output "load_balancer_arns" {
  description = "ARNs of the created load balancers"
  value       = { for k, v in awscc_elasticloadbalancingv2_load_balancer.this : k => v.id }
}

output "load_balancer_arn" {
  description = "ARN of the first load balancer"
  value       = length(awscc_elasticloadbalancingv2_load_balancer.this) > 0 ? values(awscc_elasticloadbalancingv2_load_balancer.this)[0].id : null
}

output "load_balancer_dns_names" {
  description = "DNS names of the created load balancers"
  value       = { for k, v in awscc_elasticloadbalancingv2_load_balancer.this : k => v.dns_name }
}

output "target_group_arns" {
  description = "ARNs of the created target groups"
  value       = { for k, v in awscc_elasticloadbalancingv2_target_group.this : k => v.id }
}

output "security_group_ids" {
  description = "IDs of the created security groups"
  value       = { for k, v in module.security_groups : k => v.this[k].id }
}

output "certificate_arns" {
  description = "ARNs of the created certificates"
  value       = { for k, v in aws_acm_certificate.this : k => v.arn }
}

output "dns_records" {
  description = "Created DNS records"
  value       = module.dns_records.records
}
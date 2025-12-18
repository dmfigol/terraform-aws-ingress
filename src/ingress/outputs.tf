output "load_balancers" {
  value = merge(awscc_elasticloadbalancingv2_load_balancer.this, { "tags" : {
    for tag in awscc_elasticloadbalancingv2_load_balancer.this.tags :
    tag.key => tag.value
  } })
}

output "target_groups" {
  value = merge(awscc_elasticloadbalancingv2_target_group.this, { "tags" : {
    for tag in awscc_elasticloadbalancingv2_target_group.this.tags :
    tag.key => tag.value
  } })
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
  value = module.dns_records.records
}

output "vpc_endpoint_services" {
  value = aws_vpc_endpoint_service.this
}

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

output "vpc_endpoint_services" {
  description = "Created VPC endpoint services"
  value = {
    for k, v in aws_vpc_endpoint_service.this : k => {
      id                             = v.id
      arn                            = v.arn
      service_name                   = v.service_name
      service_type                   = v.service_type
      state                          = v.state
      availability_zones             = v.availability_zones
      base_endpoint_dns_names        = v.base_endpoint_dns_names
      private_dns_name               = v.private_dns_name
      private_dns_name_configuration = v.private_dns_name_configuration
      tags                           = { for tag_key, tag_value in v.tags : tag_key => tag_value if !startswith(tag_key, "aws:") }
    }
  }
}
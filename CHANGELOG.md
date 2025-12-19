# 0.2.1 (2025-12-19)
- Change outputs to return full objects for load balancer
- Fix bug when the subsequent plan/apply fails due to bug in ELB API with enforce_security_group_inbound_rules_on_private_link_traffic attribute

# 0.2.0 (2025-12-10)
- Add VPC endpoint service
- Add target group with ALB target
- Add ALB rule pattern config
- Add explicit VPC ID argument

# 0.1.0 (2025-11-18)
Initial release supporting:
- load balancer (ALB/NLB)
- target groups
- certificates
- DNS records
- security groups

locals {
  # Extract domain names from certificates for easier access
  domain_names = {
    for cert_key, cert in var.certificates : cert_key => flatten([
      for zone, domains in cert.dns_validation : domains
    ])
  }

  # Map VPC IDs for each load balancer
  load_balancer_vpc_ids = {
    for lb_key, lb in var.load_balancers : lb_key => coalesce(lb.vpc_id, data.aws_subnet.lb_subnets[lb_key].vpc_id)
  }

  # Map VPC IDs for each security group based on which load balancers reference them
  security_group_vpc_ids = {
    for sg_key, sg in var.security_groups : sg_key => coalesce(
      # Try to get VPC ID from the first load balancer that references this security group
      try(local.load_balancer_vpc_ids[[
        for lb_key, lb in var.load_balancers : lb_key
        if contains(lb.security_groups, sg_key)
      ][0]], null),
      # Fallback to the first load balancer's VPC if no load balancers reference this SG
      local.load_balancer_vpc_ids[keys(local.load_balancer_vpc_ids)[0]]
    )
  }

  # Map VPC IDs for each target group based on which load balancers reference them
  target_group_vpc_ids = {
    for tg_key, tg in var.load_balancer_target_groups : tg_key => coalesce(
      # Try to get VPC ID from the first load balancer that references this target group
      try(local.load_balancer_vpc_ids[[
        for lb_key, lb in var.load_balancers : lb_key
        if contains([
          for listener_key, listener in lb.listeners : listener.default_action.target_group
        ], tg_key)
      ][0]], null),
      # Fallback to the first load balancer's VPC if no load balancers reference this TG
      local.load_balancer_vpc_ids[keys(local.load_balancer_vpc_ids)[0]]
    )
  }
}
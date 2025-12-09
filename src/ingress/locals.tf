locals {
  # Extract domain names from certificates for easier access
  domain_names = {
    for cert_key, cert in var.certificates : cert_key => flatten([
      for zone, domains in cert.dns_validation : domains
    ])
  }

  # Map VPC IDs for each load balancer - use lb-specific vpc_id or fall back to top-level vpc_id
  load_balancer_vpc_ids = {
    for lb_key, lb in var.load_balancers : lb_key => coalesce(lb.vpc_id, var.vpc_id)
  }

  # Map VPC IDs for each security group - use sg-specific vpc_id or fall back to top-level vpc_id
  security_group_vpc_ids = {
    for sg_key, sg in var.security_groups : sg_key => coalesce(sg.vpc_id, var.vpc_id)
  }

  # Map VPC IDs for each target group - use vpc_id from referencing load balancer or fall back to top-level vpc_id
  target_group_vpc_ids = {
    for tg_key, tg in var.load_balancer_target_groups : tg_key => coalesce(
      # Try to get VPC ID from the first load balancer that references this target group
      try(local.load_balancer_vpc_ids[[
        for lb_key, lb in var.load_balancers : lb_key
        if contains([
          for listener_key, listener in lb.listeners : listener.default_action.target_group
        ], tg_key)
      ][0]], null),
      # Fallback to top-level vpc_id if no load balancers reference this TG
      var.vpc_id
    )
  }

  # Smart defaults for health checks
  health_check_defaults = {
    for tg_key, tg in var.load_balancer_target_groups : tg_key => {
      protocol = coalesce(try(tg.health_check.protocol, null), tg.protocol)
      port     = coalesce(try(tg.health_check.port, null), tg.port)
      path = try(tg.health_check.path, null) != null ? tg.health_check.path : (
        contains(["HTTP", "HTTPS"], tg.protocol) ? "/" : null
      )
    }
  }

  # Validation: Collect all target group references from listeners
  all_listener_target_group_references = distinct(flatten([
    for lb_key, lb in var.load_balancers : [
      for listener_key, listener in lb.listeners : [
        for rule in listener.rules : rule.action.target_group
        if rule.action.target_group != null
      ]
    ]
  ]))

  # Validation: Collect all target group references from default actions
  all_default_action_target_group_references = distinct(flatten([
    for lb_key, lb in var.load_balancers : [
      for listener_key, listener in lb.listeners : listener.default_action.target_group
      if listener.default_action.target_group != null
    ]
  ]))

  # Validation: Combine all target group references
  all_target_group_references = distinct(concat(
    local.all_listener_target_group_references,
    local.all_default_action_target_group_references
  ))

  # Validation: Check for missing target groups
  missing_target_groups = [
    for tg_ref in local.all_target_group_references : tg_ref
    if !contains(keys(var.load_balancer_target_groups), tg_ref)
  ]

  # Validation error message
  validation_error_message = length(local.missing_target_groups) > 0 ? format(
    "The following target groups are referenced but not defined: %s. Available target groups: %s",
    join(", ", local.missing_target_groups),
    join(", ", keys(var.load_balancer_target_groups))
  ) : ""

  # Resolve lb@<name>:<port> notation for ALB target types
  # Format: lb@<lb_name> or lb@<lb_name>:<port>
  # If port is not specified, uses the target group's port
  resolved_target_group_targets = {
    for tg_key, tg in var.load_balancer_target_groups : tg_key => [
      for target in tg.targets : {
        # Check if target uses lb@ notation
        is_lb_ref = startswith(target, "lb@")
        # Extract lb name (part after lb@ and before optional :port)
        lb_name = startswith(target, "lb@") ? (
          length(regexall(":", substr(target, 3, length(target) - 3))) > 0 ?
          split(":", substr(target, 3, length(target) - 3))[0] :
          substr(target, 3, length(target) - 3)
        ) : null
        # Extract port if specified, otherwise use target group port
        port = startswith(target, "lb@") ? (
          length(regexall(":", substr(target, 3, length(target) - 3))) > 0 ?
          tonumber(split(":", substr(target, 3, length(target) - 3))[1]) :
          tg.port
          ) : (
          length(split(":", target)) > 1 ? tonumber(split(":", target)[1]) : null
        )
        # Original target value for non-lb@ targets
        original = target
        # ID for the target - will be resolved to ARN for lb@ or original id for others
        id = startswith(target, "lb@") ? null : split(":", target)[0]
      }
    ]
  }
}
variable "load_balancers" {
  description = "Map of load balancers to create"
  type = map(object({
    scheme = string
    type   = string
    subnet_mappings = list(object({
      subnet_id = string
    }))
    ip_address_type = optional(string, "ipv4")
    listeners = map(object({
      certificates = optional(list(string), [])
      default_action = object({
        target_group = optional(string, null)
        type         = optional(string, "forward")
        url          = optional(string, null)
        status_code  = optional(string, null)
        message_body = optional(string, null)
        content_type = optional(string, null)
      })
      rules = optional(list(object({
        priority = number
        conditions = list(object({
          field  = string
          values = list(string)
        }))
        action = object({
          target_group = optional(string, null)
          type         = optional(string, "forward")
          status_code  = optional(string, null)
          message_body = optional(string, null)
          content_type = optional(string, null)
        })
      })), [])
    }))
    security_groups = optional(list(string), [])
    dns_records = optional(map(object({
      name = optional(string, null)
      type = string
      zone = string
    })), {})
    vpc_id = optional(string, null)
  }))

  validation {
    condition = alltrue([
      for lb_name, lb in var.load_balancers :
      can(regex("^[a-zA-Z0-9]([a-zA-Z0-9-]{0,30}[a-zA-Z0-9])?$", lb_name)) &&
      !startswith(lb_name, "internal-") &&
      length(lb_name) <= 32
    ])
    error_message = "Load balancer names must be unique per region per account, can have a maximum of 32 characters, must contain only alphanumeric characters or hyphens, must not begin or end with a hyphen, and must not begin with 'internal-'."
  }

  validation {
    condition = length(flatten([
      for lb_key, lb in var.load_balancers : [
        for listener_key, listener in lb.listeners : [
          for rule in listener.rules : rule.action.target_group
          if rule.action.target_group != null && !contains(keys(var.load_balancer_target_groups), rule.action.target_group)
        ]
      ]
    ])) == 0
    error_message = "One or more target groups referenced in listener rules are not defined in load_balancer_target_groups."
  }

  validation {
    condition = length(flatten([
      for lb_key, lb in var.load_balancers : [
        for listener_key, listener in lb.listeners : listener.default_action.target_group
        if listener.default_action.target_group != null && !contains(keys(var.load_balancer_target_groups), listener.default_action.target_group)
      ]
    ])) == 0
    error_message = "One or more target groups referenced in default actions are not defined in load_balancer_target_groups."
  }
}

variable "load_balancer_target_groups" {
  description = "Map of target groups for load balancers"
  type = map(object({
    target_type = string
    protocol    = string
    port        = number
    health_check = optional(object({
      protocol = optional(string)
      port     = optional(number)
      path     = optional(string)
    }))
    targets = optional(list(string), [])
  }))

  validation {
    condition = alltrue([
      for tg_name, tg in var.load_balancer_target_groups :
      can(regex("^[a-zA-Z0-9]([a-zA-Z0-9-]{0,30}[a-zA-Z0-9])?$", tg_name)) &&
      length(tg_name) <= 32
    ])
    error_message = "Target group names must be unique per region per account, can have a maximum of 32 characters, must contain only alphanumeric characters or hyphens, and must not begin or end with a hyphen."
  }

  validation {
    condition = alltrue([
      for tg_name, tg in var.load_balancer_target_groups :
      contains(["instance", "ip", "lambda", "alb"], tg.target_type)
    ])
    error_message = "Target type must be one of: instance, ip, lambda, alb."
  }

  validation {
    condition = alltrue([
      for tg_name, tg in var.load_balancer_target_groups : tg.target_type != "alb" || (
        length(tg.targets) > 0 && alltrue([
          for target in tg.targets :
          can(regex("^arn:aws:elasticloadbalancing:[a-z0-9-]+:[0-9]{12}:loadbalancer/[a-z0-9-]+/[a-z0-9]+$", target)) ||
          can(regex("^lb@[a-zA-Z0-9][a-zA-Z0-9-]*[a-zA-Z0-9](:[0-9]+)?$", target))
        ])
      )
    ])
    error_message = "ALB target type must use either load balancer ARN format (e.g., 'arn:aws:elasticloadbalancing:us-east-1:123456789012:loadbalancer/app/my-load-balancer/50dc6c495eb0a8ad') or lb@ notation referencing a load balancer defined in load_balancers (e.g., 'lb@MyALB' or 'lb@MyALB:443')."
  }
}

variable "certificates" {
  description = "Map of certificates to create"
  type = map(object({
    dns_validation = optional(map(list(string)), {})
  }))
  default = {}
}

variable "security_groups" {
  type = map(object({
    vpc_id      = optional(string, null)
    description = optional(string, "")
    inbound = optional(list(object({
      protocol    = optional(string, "-1")
      ports       = optional(string, null) # Format: "443,8080-8081,9000". When null and protocol is -1, means all ports.
      source      = optional(string, null) # Format: "10.0.0.0/8,192.168.1.0/24,2001:db8::/32" or "sg-name"
      description = optional(string, "")
    })), [])
    outbound = optional(list(object({
      protocol    = optional(string, "-1")
      ports       = optional(string, null) # Format: "443,8080-8081,9000". When null and protocol is -1, means all ports.
      destination = optional(string, null) # Format: "10.0.0.0/8,192.168.1.0/24,2001:db8::/32" or "sg-name"
      description = optional(string, "")
    })), [])
    tags = optional(map(string), {})
  }))
  default = {}
}

variable "vpc_id" {
  description = "Default VPC ID to use for resources when not specified at the resource level"
  type        = string
  default     = null
}

variable "vpc_endpoint_services" {
  description = "Map of VPC endpoint services to create"
  type = map(object({
    load_balancers   = list(string) # Format: "lb@<lb_name>" or ARN
    private_dns_name = optional(string, null)
    dns_validation = optional(object({
      zone = string # Public hosted zone for DNS validation records
    }), null)
    acceptance_required          = optional(bool, true)
    contributor_insights_enabled = optional(bool, false) # Not yet supported by provider
    supported_regions            = optional(list(string), [])
    supported_ip_address_types   = optional(list(string), ["ipv4"])
    allow_principals             = optional(list(string), [])
    tags                         = optional(map(string), {})
  }))
  default = {}

  validation {
    condition = alltrue([
      for svc_key, svc in var.vpc_endpoint_services :
      alltrue([
        for lb in svc.load_balancers :
        can(regex("^arn:aws:elasticloadbalancing:[a-z0-9-]+:[0-9]{12}:loadbalancer/net/", lb)) ||
        can(regex("^lb@[a-zA-Z0-9][a-zA-Z0-9-]*[a-zA-Z0-9]?$", lb))
      ])
    ])
    error_message = "Load balancers must be either NLB ARNs or lb@ notation referencing a load balancer defined in load_balancers (e.g., 'lb@MyNLB')."
  }

  validation {
    condition = alltrue([
      for svc_key, svc in var.vpc_endpoint_services :
      svc.dns_validation == null || svc.private_dns_name != null
    ])
    error_message = "dns_validation can only be set when private_dns_name is provided."
  }
}

variable "common_tags" {
  description = "Common tags to apply to all taggable resources"
  type        = map(string)
  default     = {}
}

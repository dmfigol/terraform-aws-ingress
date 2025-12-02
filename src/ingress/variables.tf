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

variable "common_tags" {
  description = "Common tags to apply to all taggable resources"
  type        = map(string)
  default     = {}
}
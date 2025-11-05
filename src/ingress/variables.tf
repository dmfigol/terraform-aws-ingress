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
  description = "Map of security groups to create"
  type = map(object({
    description = string
    inbound = list(object({
      protocol    = string
      ports       = string
      source      = string
      description = string
    }))
    outbound = list(object({
      protocol    = string
      ports       = string
      source      = string
      description = string
    }))
  }))
  default = {}
}

variable "common_tags" {
  description = "Common tags to apply to all taggable resources"
  type        = map(string)
  default     = {}
}
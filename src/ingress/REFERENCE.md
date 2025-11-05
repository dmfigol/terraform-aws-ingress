<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.15.0 |
| <a name="requirement_awscc"></a> [awscc](#requirement\_awscc) | >= 1.62.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_certificates"></a> [certificates](#input\_certificates) | Map of certificates to create | <pre>map(object({<br/>    dns_validation = optional(map(list(string)), {})<br/>  }))</pre> | `{}` | no |
| <a name="input_common_tags"></a> [common\_tags](#input\_common\_tags) | Common tags to apply to all taggable resources | `map(string)` | `{}` | no |
| <a name="input_load_balancer_target_groups"></a> [load\_balancer\_target\_groups](#input\_load\_balancer\_target\_groups) | Map of target groups for load balancers | <pre>map(object({<br/>    target_type = string<br/>    protocol    = string<br/>    port        = number<br/>    health_check = object({<br/>      protocol = string<br/>      port     = number<br/>      path     = optional(string, null)<br/>    })<br/>    targets = optional(list(string), [])<br/>  }))</pre> | n/a | yes |
| <a name="input_load_balancers"></a> [load\_balancers](#input\_load\_balancers) | Map of load balancers to create | <pre>map(object({<br/>    scheme = string<br/>    type   = string<br/>    subnet_mappings = list(object({<br/>      subnet_id = string<br/>    }))<br/>    ip_address_type = optional(string, "ipv4")<br/>    listeners = map(object({<br/>      certificates = optional(list(string), [])<br/>      default_action = object({<br/>        target_group = optional(string, null)<br/>        type         = optional(string, "forward")<br/>        url          = optional(string, null)<br/>        status_code  = optional(string, null)<br/>      })<br/>      rules = optional(list(object({<br/>        priority = number<br/>        conditions = list(object({<br/>          field  = string<br/>          values = list(string)<br/>        }))<br/>        action = object({<br/>          target_group = optional(string, null)<br/>          type         = optional(string, "forward")<br/>          status_code  = optional(string, null)<br/>          message_body = optional(string, null)<br/>          content_type = optional(string, null)<br/>        })<br/>      })), [])<br/>    }))<br/>    security_groups = optional(list(string), [])<br/>    dns_records = optional(map(object({<br/>      name = optional(string, null)<br/>      type = string<br/>      zone = string<br/>    })), {})<br/>    vpc_id = optional(string, null)<br/>  }))</pre> | n/a | yes |
| <a name="input_security_groups"></a> [security\_groups](#input\_security\_groups) | Map of security groups to create | <pre>map(object({<br/>    description = string<br/>    inbound = list(object({<br/>      protocol    = string<br/>      ports       = string<br/>      source      = string<br/>      description = string<br/>    }))<br/>    outbound = list(object({<br/>      protocol    = string<br/>      ports       = string<br/>      source      = string<br/>      description = string<br/>    }))<br/>  }))</pre> | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_certificate_arns"></a> [certificate\_arns](#output\_certificate\_arns) | ARNs of the created certificates |
| <a name="output_dns_records"></a> [dns\_records](#output\_dns\_records) | Created DNS records |
| <a name="output_load_balancer_arn"></a> [load\_balancer\_arn](#output\_load\_balancer\_arn) | ARN of the first load balancer |
| <a name="output_load_balancer_arns"></a> [load\_balancer\_arns](#output\_load\_balancer\_arns) | ARNs of the created load balancers |
| <a name="output_load_balancer_dns_names"></a> [load\_balancer\_dns\_names](#output\_load\_balancer\_dns\_names) | DNS names of the created load balancers |
| <a name="output_security_group_ids"></a> [security\_group\_ids](#output\_security\_group\_ids) | IDs of the created security groups |
| <a name="output_target_group_arns"></a> [target\_group\_arns](#output\_target\_group\_arns) | ARNs of the created target groups |
<!-- END_TF_DOCS -->
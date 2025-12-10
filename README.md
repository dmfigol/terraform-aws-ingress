# Terraform modules for creating ingress on AWS
> [!IMPORTANT]
> The module is ready for sandbox and development environments. However, it is not yet production ready - API might change until we get it right. Open an issue to suggest a new feature or change in the interface. If you want to use this in production, pin to the tag.

This repository contains modules to simplify creation of ingress on AWS: load balancers, certificates, DNS records:
- Ingress | [reference](src/ingress/REFERENCE.md) 

## Usage

```hcl
module "ingress" {
  source = "git::https://github.com/dmfigol/terraform-aws-ingress.git//src/ingress?ref=0.2.0"

  vpc_id = "vpc-12345678"
  load_balancers = {
    "MyNLB" = {
      scheme          = "internet-facing"
      type            = "network"
      subnet_mappings = [{ subnet_id = "subnet-11111111" }, { subnet_id = "subnet-22222222" }]
      listeners = {
        "TCP_443" = { default_action = { target_group = "MyNLBToALB-TCP-443" } }
        "TLS_8443" = { certificates = ["MyCert"], default_action = { target_group = "MyNLB-TCP-8080" } }
      }
      security_groups = ["MyNLB"]
      dns_records = {
        "my-nlb.example.org|A" = { name = "my-nlb.example.org", type = "A", zone = "example.org" }
      }
    }
    "MyALB" = {
      type            = "application"
      scheme          = "internet-facing"
      ip_address_type = "dualstack"
      subnet_mappings = [{ subnet_id = "subnet-11111111" }, { subnet_id = "subnet-22222222" }]
      listeners = {
        "HTTPS_443" = {
          certificates   = ["MyCert"]
          default_action = { type = "fixed-response", status_code = "404", message_body = "Not Found", content_type = "text/plain" }
          rules = [
            {
              priority   = 10
              conditions = [{ field = "host-header", values = ["app.example.org"] }]
              action     = { type = "fixed-response", status_code = "200", message_body = "OK", content_type = "text/plain" }
            }
          ]
        }
        "HTTP_80" = { default_action = { type = "redirect", url = "HTTPS://#{host}:443/#{path}?#{query}", status_code = "HTTP_301" } }
      }
      security_groups = ["MyALB"]
      dns_records = {
        "my-alb.example.org|A"    = { name = "my-alb.example.org", type = "A", zone = "example.org" }
        "my-alb.example.org|AAAA" = { name = "my-alb.example.org", type = "AAAA", zone = "example.org" }
      }
    }
  }

  load_balancer_target_groups = {
    "MyNLB-TCP-8080"      = { target_type = "ip", protocol = "TCP", port = 8080 }
    "MyNLBToALB-TCP-443"  = { target_type = "alb", protocol = "TCP", port = 443, health_check = { protocol = "HTTPS", path = "/health" }, targets = ["lb@MyALB:443"] }
  }

  certificates = {
    "MyCert" = { dns_validation = { "example.org" = ["my-nlb.example.org", "my-alb.example.org", "app.example.org"] } }
  }

  security_groups = {
    "MyNLB" = {
      description = "NLB security group"
      inbound = [
        { protocol = "tcp", ports = "443,8443", source = "0.0.0.0/0", description = "HTTPS traffic" }
      ]
      outbound = [
        { destination = "0.0.0.0/0", description = "All outbound" }
      ]
    }
    "MyALB" = {
      description = "ALB security group"
      inbound = [
        { protocol = "tcp", ports = "80,443", source = "0.0.0.0/0", description = "HTTP/HTTPS traffic" }
      ]
      outbound = [
        { destination = "0.0.0.0/0", description = "All outbound" }
      ]
    }
  }

  vpc_endpoint_services = {
    "MyService" = {
      load_balancers     = ["lb@MyNLB"]
      private_dns_name   = "service.example.org"
      dns_validation     = { zone = "example.org" }
      acceptance_required = false
      supported_regions  = ["us-east-1"]
      tags               = { Service = "MyService" }
    }
  }

  common_tags = {
    Project     = "my-project"
    Environment = "dev"
    ManagedBy   = "terraform"
  }

  providers = {
    aws.dns_owner = aws.dns_owner
  }
}

provider "aws" {
  region = "us-east-1"
}

provider "awscc" {
  region = "us-east-1"
}

provider "aws" {
  alias  = "dns_owner"
  region = "us-east-1"
}
```

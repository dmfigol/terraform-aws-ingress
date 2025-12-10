module "ingress" {
  source = "../../src//ingress"

  vpc_id = var.vpc_id
  load_balancers = {
    "TestNLB" : {
      "scheme" : "internet-facing",
      "type" : "network",
      "subnet_mappings" : [for subnet_id in var.subnet_ids : { "subnet_id" : subnet_id }],
      "listeners" : {
        "TCP_443" : { "default_action" : { "target_group" : "TestNLBToALB-TCP-443" } },
        "TLS_8443" : { "certificates" : ["TestNLB"], "default_action" : { "target_group" : "TestNLB-TCP-8080" } },
        # "UDP_20000" : { "default_action" : { "target_group" : "TestNLB-UDP-20000" } },
      },
      "security_groups" : ["TestNLB"],
      "dns_records" : {
        "test-nlb.${var.domain}|A" : { "name" : "test-nlb.${var.domain}", "type" : "A", "zone" : "${var.domain}" },
        # "test-nlb.${var.domain}|AAAA" : { "type" : "AAAA", "zone" : "${var.domain}" },  # by default lb is ipv4
        "test.${var.domain}|A" : { "name" : "test.${var.domain}", "type" : "A", "zone" : "${var.domain}" },
        # "test.${var.domain}|AAAA" : { "type" : "AAAA", "zone" : "${var.domain}" },  # by default lb is ipv4
      }
    },
    "TestALB" : {
      "type" : "application",
      "scheme" : "internet-facing",
      "ip_address_type" : "dualstack",
      "subnet_mappings" : [for subnet_id in var.subnet_ids : { "subnet_id" : subnet_id }],
      "listeners" : {
        "HTTPS_443" : {
          "default_action" : { "type" : "fixed-response", "status_code" : "400", "message_body" : "<h1>404 Not Found</h1>", "content_type" : "text/html" }, "certificates" : ["TestALB"], "rules" : [
            {
              "priority" : "10",
              "conditions" : [{ "field" : "host-header", "values" : ["test-alb.${var.domain}"] }],
              "action" : { "type" : "fixed-response", "status_code" : "200", "message_body" : "<h1>Hi</h1>", "content_type" : "text/html" }
            },
            {
              "priority" : "20",
              "conditions" : [{ "field" : "host-header", "values" : ["test.${var.domain}"] }],
              "action" : { "type" : "fixed-response", "status_code" : "200", "message_body" : "<h1>Test app</h1>", "content_type" : "text/html" }
            },
            {
              "priority" : "30",
              "conditions" : [{ "field" : "path-pattern", "values" : ["/health"] }],
              "action" : { "type" : "fixed-response", "status_code" : "200", "message_body" : "{\"status\": \"ok\"}", "content_type" : "application/json" }
            },
          ],
        },
        "HTTP_80" : { "default_action" : { "type" : "redirect", "url" : "HTTPS://#{host}:443/#{path}?#{query}", "status_code" : "HTTP_301" } },
      },
      "security_groups" : ["TestALB"],
      "dns_records" : {
        "test-alb.${var.domain}|A" : { "name" : "test-alb.${var.domain}", "type" : "A", "zone" : var.domain },
        "test-alb.${var.domain}|AAAA" : { "name" : "test-alb.${var.domain}", "type" : "AAAA", "zone" : var.domain },
      }
    }
  }
  load_balancer_target_groups = {
    "TestNLB-TCP-8080" : { "target_type" : "ip", "protocol" : "TCP", "port" : 8080 },
    "TestNLB-UDP-20000" : { "target_type" : "ip", "protocol" : "UDP", "port" : 20000, "health_check" : { "protocol" : "TCP", "port" : 8080 } },
    # "AppUI-HTTP-8000" : { "target_type" : "instance", "protocol" : "HTTP", "port" : 8000, "health_check" : { "protocol" : "HTTP", "port" : 8000, "path" : "/health" }, "targets" : [
    #   "i-009ad6a5c320bf378:8000"
    # ] },
    "TestNLBToALB-TCP-443" : { "target_type" : "alb", "protocol" : "TCP", "port" : 443, "health_check" : { "protocol" : "HTTPS", "path" : "/health" }, "targets" : ["lb@TestALB:443"] },
    "TestALB-HTTPS-8089" : { "target_type" : "ip", "protocol" : "HTTPS", "port" : 8089, "targets" : [
      "10.20.2.17:8089"
    ] },
  }

  certificates = {
    "TestNLB" : { "dns_validation" : { "${var.domain}" : ["test-nlb.${var.domain}"] } },
    "TestALB" : { "dns_validation" : { "${var.domain}" : ["test-alb.${var.domain}", "test.${var.domain}"] } },
  }

  security_groups = {
    "TestNLB" = {
      "description" = "Test NLB security group"
      "inbound" = [
        { "protocol" = "tcp", "ports" = "443", "source" = "0.0.0.0/0", "description" = "Any source to listener tcp/443" },
        { "protocol" = "tcp", "ports" = "8443", "source" = "0.0.0.0/0", "description" = "Any source to listener tcp/8443" },
        { "protocol" = "udp", "ports" = "20000-20001", "source" = "0.0.0.0/0", "description" = "Any source to UDP stream 20000-20001" },
      ]
      "outbound" = [
        { "destination" = "0.0.0.0/0", "description" = "All outbound access to any destination" },
      ]
    },
    "TestALB" = {
      "description" = "Test ALB security group"
      "inbound" = [
        { "protocol" = "tcp", "ports" = "443", "source" = "0.0.0.0/0", "description" = "Any source to HTTPS listener" },
        { "protocol" = "tcp", "ports" = "80", "source" = "0.0.0.0/0", "description" = "Any source to HTTP listener" },
      ]
      "outbound" = [
        { "destination" = "0.0.0.0/0", "description" = "All outbound access to any destination" },
      ]
    },
  }

  vpc_endpoint_services = {
    "TestService" : {
      "load_balancers" : ["lb@TestNLB"],
      "private_dns_name" : "test.${var.domain}",
      "dns_validation" : { "zone" : "${var.domain}" },
      "acceptance_required" : false, # default to true
      # "contributor_insights_enabled": true,  # is not supported yet
      "supported_regions" : [var.region, "us-east-1"], # default to empty array
      # "supported_ip_address_types": ["ipv4"], $ default to ["ipv4"],
      "tags" : { "CustomTag" : "CustomValue" },
      "allow_principals" : [
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
      ],
    },
  }

  common_tags = merge({
    "Project" : "terraform-aws-ingress_dev",
    "Environment" : "dev",
    "ManagedBy" : "terraform",
    "SourceUrl" : "https://github.com/dmfigol/terraform-aws-ingress.git",
  }, var.extra_tags)

  providers = {
    aws.dns_owner = aws.dns_owner
  }
}

provider "aws" {
  region = var.region
}

provider "awscc" {
  region = var.region
}

provider "aws" {
  alias   = "dns_owner"
  region  = var.region
  profile = var.dns_owner_profile
}

variable "region" {}
variable "domain" {}
variable "dns_owner_profile" { default = null }
variable "vpc_id" {}
variable "subnet_ids" { type = list(string) }
variable "extra_tags" {
  type    = map(string)
  default = {}
}

data "aws_caller_identity" "current" {}

module "ingress" {
  source = "../../src//ingress"

  vpc_id = "vpc-0f0eec8d122aa38a7"
  load_balancers = {
    # "TestNLB" : {
    #   "scheme" : "internet-facing",
    #   "type" : "network",
    #   "subnet_mappings" : [
    #     { "subnet_id" : "subnet-0b1805f45d895548d" }
    #   ],
    #   "listeners" : {
    #     "TLS_443" : { "certificates" : ["test-nlb"], "default_action" : { "target_group" : "TestNLB-TCP-8080" } },
    #     "UDP_20000" : { "default_action" : { "target_group" : "TestNLB-UDP-20000" } },
    #   },
    #   "security_groups" : ["TestNLB"],
    #   "dns_records" : {
    #     "test-nlb.aws.dmfigol.me" : { "type" : "A", "zone" : "aws.dmfigol.me" },
    #     "api.test-nlb.aws.dmfigol.me" : { "type" : "A", "zone" : "aws.dmfigol.me" }
    #   }
    # },
    "TestALB" : {
      "type" : "application",
      "scheme" : "internet-facing",
      "ip_address_type" : "dualstack",
      "subnet_mappings" : [
        { "subnet_id" : "subnet-0b1805f45d895548d" },
        { "subnet_id" : "subnet-0a11a60179b3d265a" },
      ],
      "listeners" : {
        "HTTPS_443" : {
          "default_action" : { "type" : "fixed-response", "status_code" : "400", "message_body" : "<h1>404 Not Found</h1>", "content_type" : "text/html" }, "certificates" : ["test-alb"], "rules" : [
            {
              "priority" : "10",
              "conditions" : [{ "field" : "host-header", "values" : ["test.test-alb.${var.domain}"] }],
              "action" : { "type" : "fixed-response", "status_code" : "200", "message_body" : "<h1>Hi</h1>", "content_type" : "text/html" }
            },
          ],
        },
        "HTTP_80" : { "default_action" : { "type" : "redirect", "url" : "HTTPS://#{host}:443/#{path}?#{query}", "status_code" : "HTTP_301" } },
      },
      "security_groups" : ["TestALB"],
      "dns_records" : {
        "test-alb.${var.domain}|A" : { "name" : "test-alb.${var.domain}", "type" : "A", "zone" : var.domain },
        "test-alb.${var.domain}|AAAA" : { "name" : "test-alb.${var.domain}", "type" : "AAAA", "zone" : var.domain },
        "api.test-alb.${var.domain}|A" : { "name" : "api.test-alb.${var.domain}", "type" : "A", "zone" : var.domain },
        "api.test-alb.${var.domain}|AAAA" : { "name" : "api.test-alb.${var.domain}", "type" : "AAAA", "zone" : var.domain },
        "test.test-alb.${var.domain}|A" : { "name" : "test.test-alb.${var.domain}", "type" : "A", "zone" : var.domain },
        "test.test-alb.${var.domain}|AAAA" : { "name" : "test.test-alb.${var.domain}", "type" : "AAAA", "zone" : var.domain },
      }
    }
  }
  load_balancer_target_groups = {
    # "TestNLB-TCP-8080" : { "target_type" : "ip", "protocol" : "TCP", "port" : 8080 },
    "TestNLB-UDP-20000" : { "target_type" : "ip", "protocol" : "UDP", "port" : 20000, "health_check" : { "protocol" : "TCP", "port" : 8080 } },
    # "AppUI-HTTP-8000" : { "target_type" : "instance", "protocol" : "HTTP", "port" : 8000, "health_check" : { "protocol" : "HTTP", "port" : 8000, "path" : "/health" }, "targets" : [
    #   "i-009ad6a5c320bf378:8000"
    # ] },
    "AppAPI-HTTPS-8089" : { "target_type" : "ip", "protocol" : "HTTPS", "port" : 8089, "targets" : [
      "10.20.2.17:8089"
    ] },
  }

  certificates = {
    "test-nlb" : { "dns_validation" : { "${var.domain}" : ["test-nlb.${var.domain}", "api.test-nlb.${var.domain}"] } },
    "test-alb" : { "dns_validation" : { "${var.domain}" : ["test-alb.${var.domain}", "api.test-alb.${var.domain}", "test.test-alb.${var.domain}"] } },
  }

  security_groups = {
    "TestNLB" = {
      "vpc_id"      = "vpc-0f0eec8d122aa38a7"
      "description" = "Test NLB security group"
      "inbound" = [
        { "protocol" = "tcp", "ports" = "443", "source" = "0.0.0.0/0", "description" = "Allow access to UI" },
        { "protocol" = "udp", "ports" = "20000-20001", "source" = "0.0.0.0/0", "description" = "Allow UDP streams" },
      ]
      "outbound" = [
        { "protocol" = "-1", "ports" = "0", "destination" = "0.0.0.0/0", "description" = "Allow outbound access to any destination" },
      ]
    },
    "TestALB" = {
      "description" = "Test ALB security group"
      "inbound" = [
        { "protocol" = "tcp", "ports" = "443", "source" = "0.0.0.0/0", "description" = "Allow access to HTTPS service" },
        { "protocol" = "tcp", "ports" = "80", "source" = "0.0.0.0/0", "description" = "Allow access to HTTP service" },
      ]
      "outbound" = [
        { "protocol" = "-1", "ports" = "0", "destination" = "0.0.0.0/0", "description" = "Allow outbound access to any destination" },
      ]
    },
  }

  common_tags = {
    "Project" : "terraform-aws-ingress_dev",
    "Environment" : "dev",
    "ManagedBy" : "terraform",
    "SourceUrl" : "https://github.com/dmfigol/terraform-aws-ingress.git",
  }

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

variable "domain" {
  type = string
}

variable "region" {
  type = string
}

variable "dns_owner_profile" {
  type    = string
  default = null
}

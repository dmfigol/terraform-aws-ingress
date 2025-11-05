module "ingress" {
  source = "../../src/ingress"

  load_balancers = {
    "TestNLB" : {
      "scheme" : "internet-facing",
      "type" : "network",
      "subnet_mappings" : [
        { "subnet_id" : "subnet-0b1805f45d895548d" }
      ],
      "listeners" : {
        "TLS_443" : { "certificates" : ["test-nlb"], "default_action" : { "target_group" : "TestNLB-TCP-8080" } },
        "UDP_20000" : { "default_action" : { "target_group" : "TestNLB-UDP-20000" } },
      },
      "security_groups" : ["TestNLB"],
      "dns_records" : {
        "test-nlb.aws.dmfigol.me" : { "type" : "A", "zone" : "aws.dmfigol.me" },
        "api.test-nlb.aws.dmfigol.me" : { "type" : "A", "zone" : "aws.dmfigol.me" }
      }
    },
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
          "default_action" : { "target_group" : "AppUI-HTTP-8000" }, "certificates" : ["test-alb"], "rules" : [
            {
              "priority" : "5",
              "conditions" : [{ "field" : "host-header", "values" : ["api.test-alb.aws.dmfigol.me"] }],
              "action" : { "target_group" : "AppAPI-HTTPS-8089" }
            },
            {
              "priority" : "10",
              "conditions" : [{ "field" : "host-header", "values" : ["test.test-alb.aws.dmfigol.me"] }],
              "action" : { "type" : "fixed-response", "status_code" : "200", "message_body" : "<h1>Hi</h1>", "content_type" : "text/html" }
            },
          ],
        },
        "HTTP_80" : { "default_action" : { "type" : "redirect", "url" : "HTTPS://#{host}:443/#{path}?#{query}", "status_code" : "HTTP_301" } },
      },
      "security_groups" : ["TestALB"],
      "dns_records" : {
        "test-alb.aws.dmfigol.me|A" : { "name" : "test-alb.aws.dmfigol.me", "type" : "A", "zone" : "aws.dmfigol.me" },
        "test-alb.aws.dmfigol.me|AAAA" : { "name" : "test-alb.aws.dmfigol.me", "type" : "AAAA", "zone" : "aws.dmfigol.me" },
        "api.test-alb.aws.dmfigol.me|A" : { "name" : "api.test-alb.aws.dmfigol.me", "type" : "A", "zone" : "aws.dmfigol.me" },
        "api.test-alb.aws.dmfigol.me|AAAA" : { "name" : "api.test-alb.aws.dmfigol.me", "type" : "AAAA", "zone" : "aws.dmfigol.me" },
        "test.test-alb.aws.dmfigol.me|A" : { "name" : "test.test-alb.aws.dmfigol.me", "type" : "A", "zone" : "aws.dmfigol.me" },
        "test.test-alb.aws.dmfigol.me|AAAA" : { "name" : "test.test-alb.aws.dmfigol.me", "type" : "AAAA", "zone" : "aws.dmfigol.me" },
      }
    }
  }
  load_balancer_target_groups = {
    "TestNLB-TCP-8080" : { "target_type" : "ip", "protocol" : "TCP", "port" : 8080 },
    "TestNLB-UDP-20000" : { "target_type" : "ip", "protocol" : "UDP", "port" : 20000, "health_check" : { "protocol" : "TCP", "port" : 8080 } },
    "AppUI-HTTP-8000" : { "target_type" : "instance", "protocol" : "HTTP", "port" : 8000, "health_check" : { "protocol" : "HTTP", "port" : 8000, "path" : "/health" }, "targets" : [
      "i-009ad6a5c320bf378:8000"
    ] },
    "AppAPI-HTTPS-8089" : { "target_type" : "ip", "protocol" : "HTTPS", "port" : 8089, "targets" : [
      "10.20.2.17:8089"
    ] },
  }

  certificates = {
    "test-nlb" : { "dns_validation" : { "aws.dmfigol.me" : ["test-nlb.aws.dmfigol.me", "api.test-nlb.aws.dmfigol.me"] } },
    "test-alb" : { "dns_validation" : { "aws.dmfigol.me" : ["test-alb.aws.dmfigol.me", "api.test-alb.aws.dmfigol.me", "test.test-alb.aws.dmfigol.me"] } },
  }

  security_groups = {
    "TestNLB" = {
      "description" = "Test NLB security group"
      "inbound" = [
        { "protocol" = "tcp", "ports" = "443", "source" = "0.0.0.0/0", "description" = "Allow access to UI" },
        { "protocol" = "udp", "ports" = "20000-20001", "source" = "0.0.0.0/0", "description" = "Allow UDP streams" },
      ]
      "outbound" = [
        { "protocol" = "-1", "ports" = "0", "source" = "0.0.0.0/0", "description" = "Allow outbound access to any destination" },
      ]
    },
    "TestALB" = {
      "description" = "Test ALB security group"
      "inbound" = [
        { "protocol" = "tcp", "ports" = "443", "source" = "0.0.0.0/0", "description" = "Allow access to HTTPS service" },
        { "protocol" = "tcp", "ports" = "80", "source" = "0.0.0.0/0", "description" = "Allow access to HTTP service" },
      ]
      "outbound" = [
        { "protocol" = "-1", "ports" = "0", "source" = "0.0.0.0/0", "description" = "Allow outbound access to any destination" },
      ]
    },
  }

  common_tags = {
    "Project" : "terraform-aws-ingress_development",
    "Environment" : "dev",
    "ManagedBy" : "terraform",
    "SourceUrl" : "https://github.com/dmfigol/terraform-aws-ingress.git",
  }

  providers = {
    aws.dns_owner = aws.dns_owner
  }
}

provider "aws" {
  region = "eu-west-2"
}

provider "awscc" {
  region = "eu-west-2"
}

provider "aws" {
  alias   = "dns_owner"
  region  = "eu-west-2"
  profile = "root"
}
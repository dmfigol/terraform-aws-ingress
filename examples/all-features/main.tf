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
    }
  }
  load_balancer_target_groups = {
    "TestNLB-TCP-8080" : { "target_type" : "ip", "protocol" : "TCP", "port" : 8080, "health_check" : { "protocol" : "TCP", "port" : 8080 } },
    "TestNLB-UDP-20000" : { "target_type" : "ip", "protocol" : "UDP", "port" : 20000, "health_check" : { "protocol" : "TCP", "port" : 8080 } },
  }

  certificates = {
    "test-nlb" : { "dns_validation" : { "aws.dmfigol.me" : ["test-nlb.aws.dmfigol.me", "api.test-nlb.aws.dmfigol.me"] } },
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
    }
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
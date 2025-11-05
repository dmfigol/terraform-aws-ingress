terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      version               = ">= 6.15.0"
      configuration_aliases = [aws.dns_owner]
    }
    awscc = {
      source  = "hashicorp/awscc"
      version = ">= 1.62.0"
    }
  }
  required_version = ">= 1.5.0"
}
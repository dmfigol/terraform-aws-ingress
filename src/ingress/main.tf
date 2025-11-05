# Security Groups
module "security_groups" {
  source = "git::https://github.com/dmfigol/terraform-aws-vpc.git//src/security-groups?ref=main"

  for_each = var.security_groups

  security_groups = {
    (each.key) = each.value
  }
  vpc_id = local.security_group_vpc_ids[each.key]
}

# Certificates - Use regular AWS provider since awscc doesn't support ACM
resource "aws_acm_certificate" "this" {
  for_each = var.certificates

  domain_name       = local.domain_names[each.key][0]
  validation_method = "DNS"

  subject_alternative_names = length(local.domain_names[each.key]) > 1 ? slice(local.domain_names[each.key], 1, length(local.domain_names[each.key])) : []

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(var.common_tags, {
    Name = each.key
  })
}

# Create DNS validation records for certificate validation using the dns_records module
module "cert_validation_dns" {
  source = "git::https://github.com/dmfigol/terraform-aws-dns.git//src/dns-records?ref=main"

  dns_records = length(var.certificates) > 0 ? merge([
    for cert_key, cert in var.certificates : {
      for dvo in aws_acm_certificate.this[cert_key].domain_validation_options : "cert-validation-${cert_key}-${dvo.domain_name}" => {
        name    = dvo.resource_record_name
        type    = dvo.resource_record_type
        records = [dvo.resource_record_value]
        zone = [
          for zone, domains in cert.dns_validation : zone
          if contains(domains, dvo.domain_name)
        ][0]
        zone_type = "public"
        ttl       = 60
      }
    }
  ]...) : {}

  providers = {
    aws = aws.dns_owner
  }
}

# Certificate validation - wait for certificate to be validated before it can be used
resource "aws_acm_certificate_validation" "this" {
  for_each = var.certificates

  certificate_arn = aws_acm_certificate.this[each.key].arn
  validation_record_fqdns = length(aws_acm_certificate.this[each.key].domain_validation_options) > 0 && length(var.certificates) > 0 ? [
    for record_key, record in module.cert_validation_dns.records : record.fqdn
    if startswith(record_key, "cert-validation-${each.key}-")
  ] : []

  timeouts {
    create = "10m"
  }
}

# Target Groups
resource "awscc_elasticloadbalancingv2_target_group" "this" {
  for_each = var.load_balancer_target_groups

  name        = each.key
  port        = each.value.port
  protocol    = each.value.protocol
  target_type = each.value.target_type
  vpc_id      = local.target_group_vpc_ids[each.key]

  health_check_enabled  = true
  health_check_protocol = each.value.health_check.protocol
  health_check_port     = each.value.health_check.port

  tags = concat([
    {
      key   = "Name"
      value = each.key
    }
    ], [
    for tag_key, tag_value in var.common_tags : {
      key   = tag_key
      value = tag_value
    }
  ])
}

# Load Balancers
resource "awscc_elasticloadbalancingv2_load_balancer" "this" {
  for_each = var.load_balancers

  name   = each.key
  scheme = each.value.scheme
  type   = each.value.type

  subnet_mappings = each.value.subnet_mappings

  security_groups = length(each.value.security_groups) > 0 ? [
    for sg_key in each.value.security_groups : module.security_groups[sg_key].this[sg_key].id
  ] : null
  enforce_security_group_inbound_rules_on_private_link_traffic = each.value.type == "network" ? "off" : null

  tags = concat([
    {
      key   = "Name"
      value = each.key
    }
    ], [
    for tag_key, tag_value in var.common_tags : {
      key   = tag_key
      value = tag_value
    }
  ])
}

# Load Balancer Listeners
resource "awscc_elasticloadbalancingv2_listener" "this" {
  for_each = {
    for combo in flatten([
      for lb_key, lb in var.load_balancers : [
        for listener_key, listener in lb.listeners : {
          lb_key       = lb_key
          listener_key = listener_key
          listener     = listener
          port         = split("_", listener_key)[1]
          protocol     = split("_", listener_key)[0]
        }
      ]
    ]) : "${combo.lb_key}-${combo.listener_key}" => combo
  }

  load_balancer_arn = awscc_elasticloadbalancingv2_load_balancer.this[each.value.lb_key].id
  port              = tonumber(each.value.port)
  protocol          = each.value.protocol

  certificates = length(each.value.listener.certificates) > 0 ? [
    for cert_key in each.value.listener.certificates : {
      certificate_arn = aws_acm_certificate_validation.this[cert_key].certificate_arn
    }
  ] : null

  default_actions = [
    {
      type             = "forward"
      target_group_arn = awscc_elasticloadbalancingv2_target_group.this[each.value.listener.default_action.target_group].id
    }
  ]
}

# DNS Records - simplified without certificate validation for now
module "dns_records" {
  source = "git::https://github.com/dmfigol/terraform-aws-dns.git//src/dns-records?ref=main"

  dns_records = length(var.load_balancers) > 0 ? merge([
    for lb_key, lb in var.load_balancers : length(lb.dns_records) > 0 ? {
      for dns_key, dns in lb.dns_records : dns_key => {
        name = dns_key
        type = dns.type
        alias = {
          name                   = awscc_elasticloadbalancingv2_load_balancer.this[lb_key].dns_name
          zone_id                = awscc_elasticloadbalancingv2_load_balancer.this[lb_key].canonical_hosted_zone_id
          evaluate_target_health = true
        }
        zone      = dns.zone
        zone_type = "public" # Explicitly use public zone to avoid ambiguity
      }
    } : {}
  ]...) : {}

  providers = {
    aws = aws.dns_owner
  }
}
# Find VPC ID from subnets used in load balancers
data "aws_subnet" "lb_subnets" {
  for_each = { for lb_key, lb in var.load_balancers : lb_key => lb.subnet_mappings[0].subnet_id if lb.vpc_id == null }
  id       = each.value
}
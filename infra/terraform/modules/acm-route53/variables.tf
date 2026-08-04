variable "domain_name" { type = string }
variable "route53_zone_id" { type = string }
variable "load_balancer_arn" { type = string }
variable "load_balancer_dns_name" { type = string }
variable "load_balancer_zone_id" { type = string }
variable "target_group_arn" { type = string }
variable "tags" {
  type    = map(string)
  default = {}
}

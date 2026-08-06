variable "name_prefix" { type = string }
variable "callback_urls" { type = list(string) }
variable "logout_urls" { type = list(string) }
variable "cognito_domain_prefix" { type = string }
variable "self_registration_enabled" {
  type    = bool
  default = false
}
variable "tags" {
  type    = map(string)
  default = {}
}

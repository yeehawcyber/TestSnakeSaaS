variable "name_prefix" { type = string }
variable "callback_urls" { type = list(string) }
variable "logout_urls" { type = list(string) }
variable "cognito_domain_prefix" { type = string }
variable "tags" {
  type    = map(string)
  default = {}
}

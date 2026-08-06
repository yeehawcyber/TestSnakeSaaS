output "user_pool_id" { value = aws_cognito_user_pool.this.id }
output "user_pool_arn" { value = aws_cognito_user_pool.this.arn }
output "user_pool_client_id" { value = aws_cognito_user_pool_client.web.id }
output "self_registration_enabled" { value = var.self_registration_enabled }
output "domain_url" {
  value = "https://${aws_cognito_user_pool_domain.this.domain}.auth.${data.aws_region.current.region}.amazoncognito.com"
}

data "aws_region" "current" {}

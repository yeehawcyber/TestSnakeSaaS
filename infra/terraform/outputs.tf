output "application_url" {
  description = "AWS-managed public HTTPS URL for Snake/Shift."
  value       = aws_apigatewayv2_api.web.api_endpoint
}

output "ecr_repository_url" {
  description = "Private ECR repository used by the Lambda deployment."
  value       = module.ecr.repository_url
}

output "lambda_function_name" {
  description = "Lambda function serving the Next.js application."
  value       = aws_lambda_function.web.function_name
}

output "cognito_user_pool_id" {
  value = module.cognito.user_pool_id
}

output "cognito_client_id" {
  value = module.cognito.user_pool_client_id
}

output "cognito_domain_url" {
  value = module.cognito.domain_url
}

output "monthly_budget_name" {
  value = aws_budgets_budget.monthly_account.name
}

output "cost_guard_function_name" {
  value = aws_lambda_function.cost_guard.function_name
}

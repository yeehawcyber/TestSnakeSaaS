output "application_url" {
  description = "Public HTTPS URL for Snake/Shift."
  value       = local.public_url
}

output "ecr_repository_url" {
  description = "Private ECR repository used by the deployment workflow."
  value       = module.ecr.repository_url
}

output "ecs_cluster_name" {
  description = "ECS cluster name."
  value       = module.ecs.cluster_name
}

output "ecs_service_name" {
  description = "ECS service name."
  value       = module.ecs.service_name
}

output "cognito_user_pool_id" {
  description = "Cognito user pool ID used by the application."
  value       = module.cognito.user_pool_id
}

output "cognito_client_id" {
  description = "Public Cognito OAuth client ID."
  value       = module.cognito.user_pool_client_id
}

output "cognito_domain_url" {
  description = "Cognito hosted UI base URL."
  value       = module.cognito.domain_url
}

output "github_plan_role_arn" {
  description = "OIDC role assumed by pull-request Terraform plans."
  value       = module.github_oidc.plan_role_arn
}

output "github_deploy_role_arn" {
  description = "OIDC role assumed only by the approval-protected dev environment."
  value       = module.github_oidc.deploy_role_arn
}

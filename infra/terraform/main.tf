module "networking" {
  source = "./modules/networking"

  name_prefix        = local.name_prefix
  aws_region         = var.aws_region
  vpc_cidr           = var.vpc_cidr
  availability_zones = slice(data.aws_availability_zones.available.names, 0, 2)
  tags               = local.common_tags
}

module "security_groups" {
  source = "./modules/security-groups"

  name_prefix           = local.name_prefix
  vpc_id                = module.networking.vpc_id
  container_port        = 8080
  allowed_ingress_cidrs = var.allowed_ingress_cidrs
  tags                  = local.common_tags
}

module "ecr" {
  source = "./modules/ecr"

  name_prefix = local.name_prefix
  tags        = local.common_tags
}

module "logging" {
  source = "./modules/cloudwatch-logging"

  name_prefix       = local.name_prefix
  retention_in_days = 30
  tags              = local.common_tags
}

module "cognito" {
  source = "./modules/cognito"

  name_prefix           = local.name_prefix
  callback_urls         = ["${local.public_url}/"]
  logout_urls           = ["${local.public_url}/"]
  cognito_domain_prefix = var.cognito_domain_prefix
  tags                  = local.common_tags
}

module "iam" {
  source = "./modules/ecs-iam"

  name_prefix                  = local.name_prefix
  aws_region                   = var.aws_region
  aws_account_id               = data.aws_caller_identity.current.account_id
  partition                    = data.aws_partition.current.partition
  ecr_repository_arn           = module.ecr.repository_arn
  log_group_arn                = module.logging.log_group_arn
  bedrock_inference_profile_id = var.bedrock_inference_profile_id
  bedrock_foundation_model_id  = var.bedrock_foundation_model_id
  bedrock_model_regions        = ["us-east-1", "us-east-2", "us-west-2"]
  tags                         = local.common_tags
}

module "alb" {
  source = "./modules/alb"

  name_prefix           = local.name_prefix
  vpc_id                = module.networking.vpc_id
  public_subnet_ids     = module.networking.public_subnet_ids
  alb_security_group_id = module.security_groups.alb_security_group_id
  container_port        = 8080
  health_check_path     = "/api/health"
  tags                  = local.common_tags
}

module "dns_acm" {
  source = "./modules/acm-route53"

  domain_name            = var.domain_name
  route53_zone_id        = var.route53_zone_id
  load_balancer_arn      = module.alb.arn
  load_balancer_dns_name = module.alb.dns_name
  load_balancer_zone_id  = module.alb.zone_id
  target_group_arn       = module.alb.target_group_arn
  tags                   = local.common_tags
}

module "rollback" {
  source = "./modules/deployment-rollback"

  name_prefix              = local.name_prefix
  load_balancer_arn_suffix = module.alb.arn_suffix
  target_group_arn_suffix  = module.alb.target_group_arn_suffix
  evaluation_periods       = 3
  period_seconds           = 60
  tags                     = local.common_tags
}

module "ecs" {
  source = "./modules/ecs-fargate"

  name_prefix            = local.name_prefix
  aws_region             = var.aws_region
  private_subnet_ids     = module.networking.private_subnet_ids
  task_security_group_id = module.security_groups.task_security_group_id
  target_group_arn       = module.alb.target_group_arn
  repository_url         = module.ecr.repository_url
  image_tag              = var.image_tag
  execution_role_arn     = module.iam.execution_role_arn
  task_role_arn          = module.iam.task_role_arn
  log_group_name         = module.logging.log_group_name
  desired_count          = var.desired_count
  rollback_alarm_names   = module.rollback.alarm_names

  environment_variables = {
    AWS_REGION           = var.aws_region
    BEDROCK_MODEL_ID     = var.bedrock_inference_profile_id
    COGNITO_CLIENT_ID    = module.cognito.user_pool_client_id
    COGNITO_DOMAIN       = module.cognito.domain_url
    COGNITO_LOGOUT_URI   = "${local.public_url}/"
    COGNITO_REDIRECT_URI = "${local.public_url}/"
    COGNITO_USER_POOL_ID = module.cognito.user_pool_id
    NODE_ENV             = "production"
    PORT                 = "8080"
  }

  tags = local.common_tags

  depends_on = [module.dns_acm]
}

module "github_oidc" {
  source = "./modules/github-oidc"

  name_prefix                = local.name_prefix
  aws_region                 = var.aws_region
  aws_account_id             = data.aws_caller_identity.current.account_id
  partition                  = data.aws_partition.current.partition
  github_repository          = var.github_repository
  github_oidc_subject_prefix = var.github_oidc_subject_prefix
  github_environment         = var.environment
  create_oidc_provider       = var.create_github_oidc_provider
  existing_oidc_provider_arn = var.existing_github_oidc_provider_arn
  state_bucket_arn           = var.state_bucket_arn
  state_kms_key_arn          = var.state_kms_key_arn
  state_key                  = var.state_key
  ecr_repository_arn         = module.ecr.repository_arn
  ecs_execution_role_arn     = module.iam.execution_role_arn
  ecs_task_role_arn          = module.iam.task_role_arn
  route53_zone_id            = var.route53_zone_id
  tags                       = local.common_tags
}

run "dev_creation_plan" {
  command = plan

  variables {
    domain_name           = "dev.snake.invalid"
    route53_zone_id       = "Z0123456789EXAMPLE"
    cognito_domain_prefix = "testsnakesaas-dev-plan-only"
    image_tag             = "0000000000000000000000000000000000000000"
    state_bucket_arn      = "arn:aws:s3:::testsnakesaas-terraform-state-123456789012"
    state_kms_key_arn     = "arn:aws:kms:us-east-1:123456789012:key/00000000-0000-0000-0000-000000000000"
  }

  assert {
    condition     = module.ecs.cluster_name == "testsnakesaas-dev-cluster"
    error_message = "The dev cluster name changed unexpectedly."
  }

  assert {
    condition     = module.cognito.domain_url == "https://testsnakesaas-dev-plan-only.auth.us-east-1.amazoncognito.com"
    error_message = "The Cognito hosted domain output changed unexpectedly."
  }
}

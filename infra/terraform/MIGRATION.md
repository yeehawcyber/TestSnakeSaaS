# Architecture migration record

The original ECS/Fargate, VPC, NAT Gateway, ALB, ACM, Route 53, and ECS-oriented GitHub OIDC modules were never applied. They remain unreferenced for historical comparison and require no Terraform state migration or import. The bootstrap root now owns a separate serverless-scoped GitHub OIDC module so Actions can run routine plans and applies.

On 2026-08-05, the live root configuration was changed before its first application to use ECR, Lambda, API Gateway HTTP API, Cognito, CloudWatch Logs, and AWS Budgets. The reason was the explicit USD 10 monthly ceiling: the earlier design estimated about USD 71 per month before Bedrock and traffic.

The only state migration performed was moving bootstrap state from the initial local backend to the protected S3 backend key `testsnakesaas/bootstrap/terraform.tfstate`. The application state uses `testsnakesaas/dev/terraform.tfstate`.

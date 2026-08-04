# CloudFormation migration mapping

Read-only inventory on 2026-08-04 found no `snake-shift-services` CloudFormation stack, no matching ECR repository, no ECS cluster, no Route 53 hosted zone, and no GitHub OIDC provider in account `620649695133`. Therefore the reviewed plan is a creation plan and **no Terraform imports are currently required**.

## Resource mapping

| Retired `deploy/aws-services.yaml` logical resource/control | Terraform destination |
| --- | --- |
| `UserPool` | `module.cognito.aws_cognito_user_pool.this` |
| `DeletionPolicy: Retain`, `UpdateReplacePolicy: Retain` | Cognito deletion protection plus Terraform `prevent_destroy` |
| Verified email, recovery, password policy, optional TOTP MFA, case-insensitive email login | Equivalent explicit arguments in `modules/cognito` |
| `UserPoolClient` | `module.cognito.aws_cognito_user_pool_client.web` |
| Authorization Code, public client, openid/email/profile, token revocation | Equivalent OAuth client arguments; PKCE remains implemented by `lib/cognito-auth.ts` |
| `UserPoolDomain` | `module.cognito.aws_cognito_user_pool_domain.this` |
| `BedrockTaskRole` | `module.iam.aws_iam_role.task` and scoped inline policy |
| Nova Lite inference profile plus foundation model | Profile ARN plus the three verified backing model-region ARNs |
| CloudFormation outputs | Root Terraform outputs and ECS environment variables |
| `deploy/ecs-task-definition.example.json` | `module.ecs.aws_ecs_task_definition.this` |
| README-only ECR/ECS/ALB/logging/ACM guidance | Executable modules under `infra/terraform/modules` |

The CloudFormation template and standalone JSON task definition were removed so there is no second editable infrastructure definition. Their history remains recoverable through Git.

## Import contingency

If resources are created outside Terraform after the audit but before the first apply, stop. Do not let Terraform create duplicates and do not delete the resources. Generate import blocks or use these addresses after collecting exact IDs:

```powershell
terraform -chdir=infra/terraform import module.cognito.aws_cognito_user_pool.this <user-pool-id>
terraform -chdir=infra/terraform import module.cognito.aws_cognito_user_pool_client.web <user-pool-id>/<client-id>
terraform -chdir=infra/terraform import module.cognito.aws_cognito_user_pool_domain.this <domain-prefix>
terraform -chdir=infra/terraform import module.iam.aws_iam_role.task <role-name>
terraform -chdir=infra/terraform import module.iam.aws_iam_role_policy.task <role-name>:<inline-policy-name>
```

For an actual CloudFormation-owned resource, first create and review a transfer plan that preserves the resource while removing CloudFormation ownership. Importing into Terraform state alone does not stop CloudFormation from managing it. Never run both systems as active writers. After import, require a zero-change Terraform plan for the imported resource before any broader apply.

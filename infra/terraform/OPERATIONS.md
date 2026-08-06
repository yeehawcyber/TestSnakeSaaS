# Dev deployment and rollback

GitHub Actions on `main` is the only authorized deployment executor for the AWS `dev` environment. Production is unsupported.

Do not run `terraform apply` for the dev root from a local shell, agent, plugin, MCP server, or alternate CI system. Do not use an AWS Core plugin or skill as a deployment path. Terraform is the infrastructure definition; `.github/workflows/aws-dev.yml` is the sole deployment control plane.

## Completed control-plane bootstrap

The protected S3 state backend, GitHub OIDC provider, read-only plan role, and approval-gated deploy role have already been created from separately reviewed bootstrap plans. The bootstrap state is stored at `testsnakesaas/bootstrap/terraform.tfstate`.

The repository is configured with these non-secret variables:

| Variable | Value source |
| --- | --- |
| `AWS_PLAN_ROLE_ARN` | bootstrap output `github_plan_role_arn` |
| `AWS_DEPLOY_ROLE_ARN` | bootstrap output `github_deploy_role_arn` |
| `TF_STATE_BUCKET` | bootstrap output `state_bucket_name` |
| `TF_STATE_KMS_KEY_ARN` | bootstrap output `state_kms_key_arn` |
| `ECR_REPOSITORY_URL` | dev output `ecr_repository_url` |
| `APPLICATION_CALLBACK_URL` | dev output `application_url` |
| `COGNITO_DOMAIN_PREFIX` | `testsnakesaas-dev-620649695133` |

`BUDGET_ALERT_EMAIL` is a masked repository secret. No AWS access keys are stored in GitHub; both jobs use short-lived OIDC credentials.

The GitHub environment is named exactly `dev`, requires a human reviewer, and permits deployment only from `main`. Because the repository currently has one administrator, self-review is allowed; disabling it would deadlock every deployment.

## Pull request plan

An in-repository pull request runs validation and scanning, assumes the read-only plan role, reads remote state without acquiring a lock, and renders the proposed plan in the job summary. Fork pull requests receive no AWS role. Pull requests cannot apply.

## Approval-gated deployment from main

1. Merge only through the repository's human review process. The workflow has no auto-merge permission.
2. Open **AWS dev Terraform from main** on the `main` branch and select **Run workflow**.
3. Leave `deploy` false for a plan-only run, or select true to request a deployment.
4. Review the rendered plan. Any delete, replacement, unexpected resource, or Cognito replacement is a stop condition.
5. Approve the `dev` environment only after reviewing the plan and exact `main` commit SHA.
6. Actions reuses or publishes the immutable SHA-tagged image, applies the saved binary plan, verifies `/api/health`, and fails if the final refresh plan is not empty.

The workflow has no push trigger, schedule, production trust, long-lived AWS credential, or non-`main` apply path.

## Roll back

Revert `main` to a reviewed commit whose ECR image is retained, then run the same manual workflow with `deploy: true`. Confirm that the saved plan changes only the Lambda image before approving the `dev` environment. Never reuse a plan from another workflow run and never perform a local rollback apply.

## Emergency stop

An emergency concurrency stop is a break-glass AWS operation, not a deployment path. It requires explicit human authorization and intentionally creates Terraform drift. After the incident, restore the declared configuration only through a reviewed GitHub Actions plan and apply from `main`.

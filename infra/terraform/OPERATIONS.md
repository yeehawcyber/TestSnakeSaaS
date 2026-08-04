# Dev deployment and rollback procedure

Every mutation below is a future operator procedure. This implementation session ran no `terraform apply`, import, or AWS write operation.

## One-time prerequisites

1. Obtain or delegate a public DNS name and create an authoritative public Route 53 hosted zone. Record its zone ID.
2. Copy `terraform.tfvars.example` to ignored `terraform.tfvars` and replace the domain, zone, Cognito prefix, state ARNs, and image SHA.
3. In GitHub, create an environment named exactly `dev`. Configure required reviewers, prevent self-review where supported, and limit deployment branches to `main`.
4. Keep production absent. Do not add a production environment, production trust subject, schedule, push trigger, or auto-merge rule to this workflow.

## Stage 1: remote state bootstrap

Use a human short-lived AWS role/session. Review the bootstrap plan; do not apply until approved.

```powershell
terraform -chdir=infra/terraform/bootstrap init
terraform -chdir=infra/terraform/bootstrap fmt -check
terraform -chdir=infra/terraform/bootstrap validate
terraform -chdir=infra/terraform/bootstrap plan -out=bootstrap.tfplan
terraform -chdir=infra/terraform/bootstrap show -no-color bootstrap.tfplan
# Human approval gate
terraform -chdir=infra/terraform/bootstrap apply bootstrap.tfplan
```

The bootstrap root intentionally starts with Terraform's local backend to avoid a backend chicken-and-egg dependency. After the bucket exists, enable its ignored S3 backend file, write the dedicated bootstrap backend output, and migrate the local bootstrap state into the protected bucket:

```powershell
Copy-Item infra/terraform/bootstrap/backend.tf.example infra/terraform/bootstrap/backend.tf
terraform -chdir=infra/terraform/bootstrap output -raw bootstrap_backend_hcl |
  Set-Content -NoNewline infra/terraform/bootstrap/bootstrap-backend.hcl
terraform -chdir=infra/terraform/bootstrap init -migrate-state -backend-config=bootstrap-backend.hcl
```

The generated bootstrap backend uses `testsnakesaas/bootstrap/terraform.tfstate`, not the application key. Preserve the local state until migration succeeds and a read-only `terraform state list` against the S3 backend shows all eight bootstrap resources.

## Stage 2: OIDC and ECR foundation

Initialize the root with the ignored backend config, create a saved targeted plan for the one-time foundation, and review all dependencies pulled into the target graph. `-target` is used only to solve the initial image/OIDC dependency; it is not a normal deployment method.

```powershell
terraform -chdir=infra/terraform init -backend-config=backend.hcl
terraform -chdir=infra/terraform plan `
  -target=module.ecr `
  -target=module.github_oidc `
  -out=foundation.tfplan
terraform -chdir=infra/terraform show -no-color foundation.tfplan
# Human approval gate
terraform -chdir=infra/terraform apply foundation.tfplan
```

Copy the Terraform outputs and backend values into these non-secret GitHub repository/environment variables:

- `AWS_PLAN_ROLE_ARN`
- `AWS_DEPLOY_ROLE_ARN`
- `TF_STATE_BUCKET_NAME`
- `TF_STATE_BUCKET_ARN`
- `TF_STATE_KMS_KEY_ARN`
- `DEV_DOMAIN_NAME`
- `DEV_ROUTE53_ZONE_ID`
- `DEV_COGNITO_DOMAIN_PREFIX`

The role ARNs and IDs are configuration, not AWS access keys. Do not create `AWS_ACCESS_KEY_ID` or `AWS_SECRET_ACCESS_KEY` secrets.

## Pull request review

An in-repository pull request runs formatting, both Terraform validations, a container build, a HIGH/CRITICAL Trivy scan, OIDC authentication to the plan-only role, and a remote-state dev plan. Fork pull requests receive no AWS credentials. Review the plan in the job summary. The workflow never merges the pull request.

## Approval-gated dev deployment

1. Merge only through the repository's normal human review process; this workflow has no auto-merge permission.
2. Open **Actions > AWS dev infrastructure and deployment > Run workflow** on the exact commit/ref.
3. Choose `deploy`.
4. Review the preflight results.
5. A required reviewer approves the `dev` environment before the job obtains AWS credentials, pushes an image, plans, or applies.
6. The gated job rebuilds and rescans the exact commit, pushes only the full commit SHA to the immutable ECR repository, saves a Terraform plan, adds it to the run summary, applies that exact binary plan, waits for ECS steady state, and calls `/api/health`.

For the very first full deployment, the ECS circuit breaker has no earlier `COMPLETED` service deployment to restore. The exact plan and healthy image check are therefore especially important.

## Automatic rollback

The ECS rolling service has both:

- deployment circuit breaker rollback when tasks cannot reach steady state; and
- CloudWatch alarm rollback when ALB targets remain unhealthy for three consecutive one-minute periods after the ECS grace period.

Rollback requires a previous ECS deployment in `COMPLETED` state. Failed first deployments stop rather than restoring a nonexistent revision.

## Manual rollback to a retained image

1. Identify a known-good 40-character commit tag still retained in ECR.
2. Run the same workflow manually with mode `rollback` and that SHA in `image_sha`.
3. A required `dev` reviewer approves the job.
4. The job verifies the tag exists, creates a Terraform plan changing the task definition back to that immutable image, applies the exact plan, waits for steady state, and verifies `/api/health`.

For an in-progress ECS deployment that must be stopped immediately, a human operator can first inspect service deployments and then request ECS-native rollback:

```powershell
aws ecs list-service-deployments `
  --cluster <cluster-name> `
  --service <service-name> `
  --region us-east-1

aws ecs stop-service-deployment `
  --service-deployment-arn <in-progress-deployment-arn> `
  --stop-type ROLLBACK `
  --region us-east-1
```

That command is intentionally not automated. Confirm the exact deployment ARN and obtain human approval before running it.

## Infrastructure rollback

Revert the Terraform code to the last reviewed commit, run a fresh plan against remote state, inspect replacements/deletions, and apply only after approval. Never reuse an old binary plan after state or configuration has changed. Cognito, the remote-state bucket and KMS key, and the ALB have destruction/deletion protection; do not weaken those controls to force a rollback.

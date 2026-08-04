# TestSnakeSaaS Terraform

This directory is the sole infrastructure source of truth for the TestSnakeSaaS dev environment in `us-east-1`. The retired CloudFormation template and example ECS task definition have been removed; their resources and controls are represented here as executable Terraform.

No configuration in this repository targets production. The root variable validations reject any environment other than `dev` and any region other than `us-east-1`.

## Architecture

| Module | Responsibility |
| --- | --- |
| `remote-state` | Versioned, private S3 state with enforced customer-managed KMS encryption and native S3 lockfile support |
| `networking` | Two-AZ VPC, public ALB subnets, private task subnets, single dev NAT gateway, and an S3 gateway endpoint |
| `security-groups` | Internet-to-ALB 80/443, ALB-to-task 8080, and task HTTPS egress only |
| `ecr` | AES-256 encrypted private repository, immutable tags, scan on push, and bounded retention |
| `cloudwatch-logging` | Thirty-day ECS application log group |
| `cognito` | Email user pool, optional TOTP MFA, deletion protection, public Authorization Code client, and hosted domain |
| `ecs-iam` | Separate execution and task roles; task access is limited to Nova Lite invocation |
| `alb` | Internet-facing ALB, HTTP redirect, IP target group, and `/api/health` checks |
| `acm-route53` | DNS-validated ECDSA certificate, TLS 1.2/1.3 listener, and Route 53 alias |
| `deployment-rollback` | ALB unhealthy-target alarm consumed by ECS deployment alarm rollback |
| `ecs-fargate` | Fargate cluster, hardened task definition, rolling service, circuit breaker, and alarm rollback |
| `github-oidc` | GitHub OIDC provider plus separate PR-plan and approval-gated dev-deploy roles |

The Fargate container remains non-root (`1000:1000`), unprivileged, capability-free, and read-only at the root filesystem. It exposes only port `8080`, uses blocking CloudWatch logging, and has both container and ALB health checks on `/api/health`.

## Required inputs

Copy `terraform.tfvars.example` to the ignored `terraform.tfvars` and replace every example value. A public Route 53 hosted zone must already be authoritative for `domain_name`; the AWS account had no hosted zones during the 2026-08-04 audit, so DNS ownership/delegation is a prerequisite rather than an assumption.

The `image_tag` must be a full lowercase 40-character Git commit SHA. ECR rejects attempts to overwrite an existing tag.

## Review documents

- [PLAN.md](PLAN.md) — plan commands, reviewed resource summary, and current validation status.
- [COSTS.md](COSTS.md) — dev cost estimate and variable-cost assumptions.
- [IAM_REQUIREMENTS.md](IAM_REQUIREMENTS.md) — bootstrap, runtime, plan, and deploy permissions.
- [MIGRATION.md](MIGRATION.md) — CloudFormation-to-Terraform mapping and import contingency.
- [OPERATIONS.md](OPERATIONS.md) — approval-gated bootstrap, deploy, verification, and rollback procedures.

## Local validation (no AWS changes)

```powershell
terraform -chdir=infra/terraform fmt -check -recursive
terraform -chdir=infra/terraform/bootstrap init
terraform -chdir=infra/terraform/bootstrap validate
terraform -chdir=infra/terraform/bootstrap test
terraform -chdir=infra/terraform init -backend=false
terraform -chdir=infra/terraform validate
terraform -chdir=infra/terraform test
```

Never commit `terraform.tfvars`, `backend.hcl`, state, or saved binary plans. The directory-level `.gitignore` excludes them.

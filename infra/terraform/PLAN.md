# Terraform plan for review

Plan date: 2026-08-04. Target: dev in `us-east-1`.

## Current AWS inventory

Read-only checks found no `snake-shift-services` CloudFormation stack, no matching ECR repository, no ECS cluster, no Route 53 hosted zone, and no GitHub OIDC provider. The Bedrock system inference profile `us.amazon.nova-lite-v1:0` is active and routes to Nova Lite in `us-east-1`, `us-east-2`, and `us-west-2`.

## Commands

Remote state bootstrap plan:

```powershell
terraform -chdir=infra/terraform/bootstrap init
terraform -chdir=infra/terraform/bootstrap plan -out=bootstrap.tfplan
terraform -chdir=infra/terraform/bootstrap show -no-color bootstrap.tfplan
```

Dev creation plan after the backend exists:

```powershell
terraform -chdir=infra/terraform init -backend-config=backend.hcl
terraform -chdir=infra/terraform plan -lock-timeout=5m -out=dev.tfplan
terraform -chdir=infra/terraform show -no-color dev.tfplan
```

## Reviewed plan result

Terraform 1.15.8 with AWS provider 6.57.1 produced these provider-backed, plan-only results on 2026-08-04:

- account-specific remote-state bootstrap (`testsnakesaas-terraform-state-620649695133`): **8 to add, 0 to change, 0 to destroy**;
- complete dev root: **58 to add, 0 to change, 0 to destroy**.

The bootstrap plan creates one KMS key and alias plus one private, versioned, KMS-encrypted S3 bucket and its ownership, public-access, encryption, versioning, TLS-only, and designated-KMS-key policy controls.

The dev plan is creation-only against the audited account and includes:

- one two-AZ VPC with four subnets, Internet/NAT routing, one Elastic IP, and an S3 gateway endpoint;
- ALB/task security groups and explicit rules;
- one immutable/scanned ECR repository with a lifecycle policy;
- one CloudWatch log group and one unhealthy-target rollback alarm;
- Cognito user pool, public code-flow client, and hosted domain;
- ECS execution/task roles and inline policies;
- ALB, target group, HTTP redirect, ACM certificate, DNS validation records, HTTPS listener, and application alias;
- ECS cluster, hardened task definition, and Fargate service with two rollback mechanisms; and
- GitHub OIDC provider plus plan/deploy roles and scoped inline policies.

| Module | Add | Change | Destroy |
| --- | ---: | ---: | ---: |
| networking | 19 | 0 | 0 |
| security groups | 7 | 0 | 0 |
| GitHub OIDC/IAM | 10 | 0 | 0 |
| ACM/Route 53 | 5 | 0 | 0 |
| ECS execution/task IAM | 4 | 0 | 0 |
| ALB | 3 | 0 | 0 |
| Cognito | 3 | 0 | 0 |
| ECS Fargate | 3 | 0 | 0 |
| ECR | 2 | 0 | 0 |
| CloudWatch logging | 1 | 0 | 0 |
| deployment rollback alarm | 1 | 0 | 0 |
| **Dev total** | **58** | **0** | **0** |

No destroy or import action is expected. Any non-creation action, existing-resource conflict, or proposed Cognito replacement is a stop condition requiring a new migration review.

The dev result was generated with `terraform test` using placeholder DNS, state ARNs, Cognito prefix, and a zero commit SHA. It evaluates the real AWS provider and complete dependency graph but does not read a not-yet-created remote state backend. It is therefore a configuration creation plan for review, not an apply-ready live-state plan. The pull-request workflow will produce the authoritative refresh plan after the state/OIDC foundation and real Route 53 inputs exist.

## Validation status

- `terraform fmt -check -recursive`: passed
- bootstrap `terraform validate`: passed
- dev root `terraform validate`: passed
- bootstrap plan test: passed (1/1)
- dev plan test: passed (1/1)
- GitHub Actions workflow: actionlint 1.7.12 passed
- application: all 10 tests, ESLint, Vinext build, and AWS Next.js build passed
- production dependencies: `npm audit --omit=dev --audit-level=high` found 0 vulnerabilities
- container: build passed; Trivy 0.73.0 found 0 HIGH/CRITICAL findings; non-root/read-only `/api/health` returned HTTP 200
- no Terraform apply, import, state mutation, or AWS write call was run

No plan is approval to apply.

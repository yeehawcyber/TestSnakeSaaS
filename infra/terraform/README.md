# TestSnakeSaaS Terraform

This directory is the infrastructure source of truth for the cost-bounded `dev` environment in `us-east-1`.

## Deployed architecture

| Resource | Responsibility |
| --- | --- |
| S3 + KMS bootstrap | Private, versioned, encrypted Terraform state with native lockfiles |
| ECR | Immutable, scanned Lambda container images with bounded retention |
| Lambda | On-demand Next.js server with 1 GB memory, 30-second timeout, and reserved concurrency 2 |
| API Gateway HTTP API | AWS-managed HTTPS endpoint with 2 requests/second and burst 4 throttling |
| Cognito Lite | Hosted PKCE login; public self-registration is disabled |
| CloudWatch Logs | Seven-day Lambda log retention |
| AWS Budget | Account-wide USD 10 monthly budget |
| Cost guard | Budget alerts invoke a dedicated Lambda that disables web concurrency |
| IAM | Lambda can write only its log group and invoke only Nova Lite |

There is no VPC, NAT Gateway, ALB, public IPv4 allocation, Route 53 hosted zone, or custom domain. The application URL is the `application_url` Terraform output.

## Deployment execution authority

GitHub Actions on `main` is the only deployment execution authority for the AWS `dev` environment. Terraform remains the infrastructure definition, but the dev root must never be applied from a developer shell, agent, plugin, MCP server, or other local automation.

1. Pull requests run formatting, validation, Terraform tests, a container vulnerability scan, and a read-only remote-state plan through GitHub OIDC.
2. A manual `workflow_dispatch` run from `main` creates and renders a saved plan. Dispatches from any other ref cannot reach the plan or apply jobs.
3. Selecting `deploy: true` sends the apply job through the reviewer-protected GitHub `dev` environment.
4. After approval, Actions publishes the immutable image, applies that exact saved plan, verifies `/api/health`, and requires a final no-change plan.

The one-time state/OIDC control-plane bootstrap was completed before this policy took effect. It is not an application deployment path. All subsequent application plans, applies, rollbacks, and drift reconciliation must run through the checked-in workflow from `main`.

The `image_tag` is the immutable 40-character GitHub commit SHA. Never commit `terraform.tfvars`, backend files, state, or saved plans.

See [COSTS.md](COSTS.md), [OPERATIONS.md](OPERATIONS.md), and [IAM_REQUIREMENTS.md](IAM_REQUIREMENTS.md).

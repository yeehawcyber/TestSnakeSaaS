# IAM requirements

## Runtime roles

Terraform creates two separate ECS roles:

- The execution role can obtain an ECR registry token, pull layers only from the project repository, and create/write streams only in the project log group.
- The task role can call only `bedrock:InvokeModel` and `bedrock:InvokeModelWithResponseStream` on `us.amazon.nova-lite-v1:0` and the exact Nova Lite foundation-model ARNs in `us-east-1`, `us-east-2`, and `us-west-2`.

Both roles trust only `ecs-tasks.amazonaws.com` and include `aws:SourceAccount` plus a region/account-scoped ECS `aws:SourceArn` confused-deputy condition. The execution role is never given application permissions, and the task role is never given ECR or log-delivery permissions.

The application TypeScript was also checked with deterministic IAM Policy Autopilot:

```powershell
uvx iam-policy-autopilot@latest generate-policies `
  C:\Users\carlo\Documents\TestSnakeSaaS\app\api\chat\route.ts `
  --region us-east-1 `
  --account 620649695133 `
  --service-hints bedrock `
  --tf-dir C:\Users\carlo\Documents\TestSnakeSaaS\infra\terraform `
  --pretty
```

Autopilot confirmed streaming invocation but conservatively emitted wildcard bearer-token/tool and optional-guardrail permissions. Those broader permissions were rejected because the authoritative CloudFormation control and requested migration scope allow only model invocation. No policy was uploaded.

## GitHub OIDC roles

The module creates no IAM users or access keys.

- The plan role trusts only this repository's immutable OIDC subject ending in `:pull_request`. The workflow refuses AWS authentication for fork-origin pull requests. It can decrypt/read the dev state object and inspect infrastructure, but cannot write state, acquire/delete the state lock, or mutate AWS resources; PR plans therefore run with `-lock=false`.
- The deploy role trusts only the immutable subject ending in `:environment:dev`. GitHub's `dev` environment must require human reviewers. Its session can manage the enumerated dev networking, ECS, ALB, ECR, logging, Cognito, ACM, and Route 53 resources.
- `iam:PassRole` is limited to the two ECS runtime roles and `iam:PassedToService=ecs-tasks.amazonaws.com`.
- The deploy role cannot modify the GitHub OIDC provider, its own role, or the plan role. Changes to those trust controls require the bootstrap administrator and a separately reviewed plan.

## Bootstrap operator

The first two reviewed stages require a human AWS principal because the OIDC roles and state backend do not yet exist. That principal needs only the actions required by the reviewed plans, broadly grouped as:

1. State bootstrap: `s3:CreateBucket`, bucket encryption/versioning/public-access/policy/tag operations, and KMS create/alias/policy/tag/rotation operations.
2. OIDC foundation: IAM OIDC provider create/tag, project role create/tag/inline-policy operations, and the dependencies shown by the targeted foundation plan (ECR, log group, and ECS runtime roles).
3. `iam:PassRole` is not required merely to create the foundation; it is required when the full ECS service is later applied.

Do not grant long-lived administrator credentials to GitHub. Use a human SSO/role session for bootstrap, inspect the saved plans, and remove any temporary bootstrap grant after OIDC is operational.

Before applying in any account with permission boundaries, SCPs, or tag policies, use IAM Access Analyzer/Policy Simulator against the generated plan. The workflow's role policies intentionally enumerate service actions rather than attach `AdministratorAccess` or `PowerUserAccess`.

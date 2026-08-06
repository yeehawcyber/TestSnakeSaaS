# IAM requirements

## Runtime role

Terraform creates `testsnakesaas-dev-lambda`, trusted only by `lambda.amazonaws.com` for this account. Its inline policy permits:

- `logs:CreateLogStream` and `logs:PutLogEvents` only in `/aws/lambda/testsnakesaas-dev-web`;
- `bedrock:InvokeModel` and `bedrock:InvokeModelWithResponseStream` only for the configured Nova Lite inference profile and its US backing model ARNs.

The application receives no long-term AWS keys. Lambda supplies short-lived role credentials.

## GitHub Actions roles

The bootstrap root creates an account GitHub OIDC provider and two repository-scoped roles:

- `github-actions-testsnakesaas-dev-plan` trusts only in-repository pull requests and the `main` ref. It can read the dev state and infrastructure but cannot acquire a state lock, publish an image, or mutate AWS.
- `github-actions-testsnakesaas-dev-deploy` trusts only the reviewer-protected `dev` environment. It can write the single dev state object and lock, publish to the project ECR repository, and manage the serverless resources declared by the dev root.

`iam:PassRole` is limited to `testsnakesaas-dev-lambda` with `iam:PassedToService=lambda.amazonaws.com`. Neither role can modify the OIDC provider or either GitHub role. Those trust controls remain in the separately applied bootstrap state.

No AWS access keys are stored in GitHub. Actions obtains short-lived credentials through OIDC.

## Bootstrap operator

The one-time bootstrap plan has been applied and verified with a no-change refresh plan. It created only the state/OIDC control plane. GitHub Actions on `main` is now the only authorized executor for the application dev root; local agents, plugins, MCP servers, and alternate CI systems must not deploy it.

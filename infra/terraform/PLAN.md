# Applied dev plan record

Deployment date: 2026-08-05. Account: `620649695133`. Region: `us-east-1`.

- Remote-state bootstrap: 8 added, 0 changed, 0 destroyed.
- ECR foundation: 2 added, 0 changed, 0 destroyed.
- Serverless application: 13 added, 0 changed, 0 destroyed.
- Cognito callback finalization: 0 added, 2 changed in place, 0 destroyed.
- Automatic cost guard: 8 added, 1 budget changed in place, 0 destroyed.
- Final refresh plan: no changes.

Application endpoint: `https://un65jeamp5.execute-api.us-east-1.amazonaws.com`

The applied architecture intentionally replaced the earlier un-applied ECS/NAT/ALB proposal because its estimated fixed cost was incompatible with the USD 10 monthly constraint.

Validation obtained:

- Terraform formatting, validation, and test: passed.
- Application tests: 10/10 passed.
- ESLint, Vinext build, and Next.js build: passed.
- Local non-root, read-only container health check: passed.
- ECR scan: complete with no reported findings.
- Deployed `/api/health`: HTTP 200.
- Deployed home page: HTTP 200 and contains Snake/Shift.
- Cognito runtime configuration: configured for the API Gateway endpoint.
- Budget thresholds, SNS subscription, and cost-guard Lambda dry-run authorization: verified.

## GitHub Actions migration

The approved bootstrap plan was applied on 2026-08-05, adding the GitHub OIDC provider, a read-only plan role, and an approval-gated deploy role: **8 added, 0 changed, 0 destroyed**. It did not change the running application. The post-apply bootstrap refresh plan reported no changes.

Access Analyzer reported no findings for all five inline policies; Terraform formatting, validation, and both plan tests passed; actionlint passed. After this workflow branch is reviewed and merged, GitHub Actions on `main` is the only authorized executor for dev remote-state plans, immutable image publication, exact saved-plan applies, health verification, rollbacks, and drift reconciliation. AWS Core tooling and local automation are not deployment paths.

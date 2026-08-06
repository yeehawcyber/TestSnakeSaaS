# Cost envelope

Estimate date: 2026-08-05. Region: US East (N. Virginia). This is a planning estimate, not a billing guarantee.

## Current fixed baseline

| Component | Monthly estimate | Assumption |
| --- | ---: | --- |
| Terraform state KMS key | $1.00 | One customer-managed key before future rotation charges |
| ECR storage | about $0.01 | Current image is about 75 MB at the documented private-storage rate |
| S3 state | less than $0.01 | Small state and lock objects |
| Lambda, HTTP API, Cognito Lite | $0.00 at current low usage | Expected to remain inside applicable Free Tier/credit allowances |

Calculated fixed planning baseline: **about $1.02/month**, leaving about **$8.98/month** of nominal room for Lambda, API Gateway, logs, transfer, and Bedrock usage.

## Guardrails

- Account plan: AWS Free Plan, active, with $100 credit remaining when checked on 2026-08-05; credits expire 2027-01-21.
- Account-wide monthly AWS Budget: USD 10.
- Automatic cost guard: at 80% actual or 100% forecast, AWS Budgets publishes to SNS and a dedicated Lambda sets the web Lambda concurrency to zero.
- API Gateway throttle: 2 requests/second, burst 4.
- Lambda reserved concurrency: 2; no provisioned concurrency.
- Cognito player self-registration: enabled.
- CloudWatch log retention: seven days.
- ECR: immutable tags and bounded lifecycle retention.

AWS Budgets is delayed and does not stop usage in real time. The automatic guard reduces exposure after an alert, but Bedrock, Lambda duration, logs, transfer, and abusive public traffic remain variable costs. Add a notification email and review Billing regularly; no AWS configuration can honestly guarantee a hard USD 10 ceiling after usage occurs.

Official references: [Lambda pricing](https://aws.amazon.com/lambda/pricing/), [API Gateway pricing](https://aws.amazon.com/api-gateway/pricing/), [Cognito pricing](https://aws.amazon.com/cognito/pricing/), [ECR pricing](https://aws.amazon.com/ecr/pricing/), [KMS pricing](https://aws.amazon.com/kms/pricing/), and [Bedrock pricing](https://aws.amazon.com/bedrock/pricing/).

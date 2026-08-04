# Estimated dev AWS cost

Estimate date: 2026-08-04. Region: US East (N. Virginia). This is a planning estimate, not a quote. It assumes one Linux/x86 Fargate task at 0.25 vCPU and 0.5 GB for 730 hours, one NAT gateway, one ALB across two Availability Zones, three charged public IPv4 addresses (two ALB addresses plus the NAT Elastic IP), low traffic, 2 GB of ECR images, and one Route 53 hosted zone.

| Component | Monthly estimate | Assumption |
| --- | ---: | --- |
| Fargate | $9.01 | 0.25 vCPU + 0.5 GB, continuously running |
| NAT gateway | $32.85 | $0.045/hour; data processing is additional |
| Application Load Balancer | $16.43 | $0.0225/hour; LCUs are additional |
| Public IPv4 | $10.95 | Three addresses at $0.005/hour |
| Terraform state KMS key | $1.00 | One customer-managed key; low request volume |
| Route 53 hosted zone | $0.50 | First 25-zone price; DNS queries additional |
| ECR storage | $0.20 | 2 GB at $0.10/GB-month |
| S3 remote state | <$0.01 | Tiny versioned state and lock objects |
| ACM public certificate | $0.00 | AWS-issued public certificate used with the ALB |
| Cognito | $0.00 | Below the 10,000 direct-user MAU free tier for Lite/Essentials |

Expected fixed/near-fixed subtotal: **about $71/month**, before ALB LCUs, NAT data processing, internet data transfer, CloudWatch logs, Bedrock, DNS registration, taxes, or shared-account free-tier consumption. A practical low-traffic budget is **$71-$80/month plus Bedrock usage**.

Variable charges:

- NAT data processing: approximately $0.045/GB, plus applicable transfer charges.
- ALB: $0.008 per LCU-hour. At an average 0.1 LCU for 730 hours, add about $0.58/month.
- CloudWatch Logs: budget $0.50/GB ingested and about $0.03/GB-month archived after any account-level free tier.
- ECS Container Insights metrics and its log/metric ingestion are usage-dependent and excluded from the subtotal; verify the projected task/service metric volume before approval.
- Bedrock Nova Lite: token-based on-demand pricing. Use the current Bedrock price table and actual input/output token metrics; no usage volume was supplied, so it is not included in the subtotal.
- Cognito email delivery, Route 53 queries, and domain registration are usage-dependent and excluded.

The single NAT gateway is an explicit dev cost/availability tradeoff. A production design would normally use one NAT per AZ or private endpoints plus another resilient egress path, but production is outside this root module.

Official pricing references: [Fargate](https://aws.amazon.com/fargate/pricing/), [Elastic Load Balancing](https://aws.amazon.com/elasticloadbalancing/pricing/), [VPC/NAT/public IPv4](https://aws.amazon.com/vpc/pricing/), [CloudWatch](https://aws.amazon.com/cloudwatch/pricing/), [ECR](https://aws.amazon.com/ecr/pricing/), [KMS](https://aws.amazon.com/kms/pricing/), [Cognito](https://aws.amazon.com/cognito/pricing/), [Route 53](https://aws.amazon.com/route53/pricing/), and [Bedrock](https://aws.amazon.com/bedrock/pricing/).

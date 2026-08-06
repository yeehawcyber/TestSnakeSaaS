# Snake/Shift

Snake/Shift is a responsive, authenticated browser-based Snake game built with Next.js and React. It supports keyboard and touch controls, a progressive six-level speed curve, pause/restart flows, and a best score stored only on the player’s device. AWS Cognito protects player access, while the in-game Shift assistant streams responses from Amazon Bedrock.

## Play locally

Requirements: Node.js 22.13 or newer.

```powershell
npm ci
Copy-Item .env.example .env.local
npm run dev
```

Fill `.env.local` with the outputs from the reviewed Terraform dev deployment before starting. Open `http://localhost:3000` and sign in through Cognito. In the game, use the arrow keys or WASD. Space pauses the run; R resets it.

For local Bedrock chat, the AWS SDK uses the standard local AWS credential chain. AWS credentials do not belong in `.env.local` or in browser code.

## Validate the app

```powershell
npm test
npm run lint
npm run build
npm run build:aws
```

- `npm run build` validates the site runtime used by the local preview.
- `npm run build:aws` creates the standalone Node.js server used by the container.

## Run the production container

```powershell
docker build -t snake-shift-web .
docker run --rm -p 8080:8080 snake-shift-web
```

The game is served at `http://localhost:8080`. Local container and deployed API health checks use `GET /api/health`.

## AWS infrastructure

Terraform under `infra/terraform` is the sole infrastructure source of truth. It defines encrypted remote state, ECR, a container-image Lambda, a throttled API Gateway HTTP API, Cognito, seven-day CloudWatch logging, least-privilege Nova Lite access, and an account-wide USD 10 monthly budget.

Start with the [Terraform review guide](infra/terraform/README.md), then review the saved-plan, cost, IAM, migration, deployment, and rollback documents it links. The configuration is limited to dev in `us-east-1`. Terraform is the infrastructure definition, and GitHub Actions on `main` is the only authorized executor for dev plans and applies. Never apply the dev root locally.

The default chat model is the `us.amazon.nova-lite-v1:0` inference profile. The Lambda role permits only model invocation on that profile and its verified US backing models.

The app exchanges Cognito authorization codes in the browser with PKCE. The `/api/chat` server route independently verifies every Cognito access token before invoking Bedrock. Chat prompts are bounded, history is normalized, requests are rate-limited per authenticated user and task, and Bedrock output is streamed to the chat panel. Optional Bedrock Guardrail identifiers can be supplied through the documented environment variables.

## AWS deployment target

The image is deployed from a private, immutable-tag ECR repository to Lambda through AWS Lambda Web Adapter. API Gateway supplies the stable AWS-managed HTTPS endpoint, so no paid domain, Route 53 zone, NAT Gateway, public IPv4 address, or load balancer is required. Pull requests validate and plan through a read-only OIDC role. Only an explicitly dispatched workflow on `main` can request an apply, and that apply requires approval in the `dev` environment before using the separate scoped deploy role.

## Project structure

- `app/page.tsx` — game interface, canvas rendering, input, and run lifecycle.
- `app/use-cognito-auth.ts` — Cognito hosted-login, PKCE callback, session, and logout flow.
- `app/api/chat/route.ts` — authenticated Bedrock ConverseStream server endpoint.
- `app/components/game-chat.tsx` — streaming in-game assistant interface.
- `lib/snake-engine.ts` — deterministic game rules and collision logic.
- `lib/chat-validation.ts` — bounded, deterministic validation for Bedrock requests.
- `tests/` — unit coverage for gameplay and chat request validation.
- `Dockerfile` — multi-stage AWS-ready production image.
- `infra/terraform` — complete, modular dev AWS infrastructure and operational review package.
- `.github/workflows/aws-dev.yml` — OIDC-only Terraform validation, plan, approval-gated apply, image scanning, and deployment verification.

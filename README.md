# Snake/Shift

Snake/Shift is a responsive, authenticated browser-based Snake game built with Next.js and React. It supports keyboard and touch controls, a progressive six-level speed curve, pause/restart flows, and a best score stored only on the player’s device. AWS Cognito protects player access, while the in-game Shift assistant streams responses from Amazon Bedrock.

## Play locally

Requirements: Node.js 22.13 or newer.

```powershell
npm ci
Copy-Item .env.example .env.local
npm run dev
```

Fill `.env.local` with the outputs from the AWS services stack before starting. Open `http://localhost:3000` and sign in through Cognito. In the game, use the arrow keys or WASD. Space pauses the run; R resets it.

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

The game is served at `http://localhost:8080`. Container and load-balancer health checks can use `GET /api/health`.

## Create Cognito and Bedrock access

`deploy/aws-services.yaml` creates:

- a Cognito user pool with verified email sign-in, optional authenticator-app MFA, and deletion protection;
- an OAuth public client using Authorization Code + PKCE with no client secret;
- a Cognito hosted domain;
- a least-privilege ECS task role for the selected Bedrock inference profile and its underlying foundation model.

Deploy the stack after choosing exact callback, logout, and globally unique Cognito domain values:

```powershell
aws cloudformation deploy `
  --template-file deploy/aws-services.yaml `
  --stack-name snake-shift-services `
  --capabilities CAPABILITY_IAM `
  --parameter-overrides `
    CallbackUrl=http://localhost:3000/ `
    LogoutUrl=http://localhost:3000/ `
    CognitoDomainPrefix=replace-with-a-unique-prefix
```

Read the stack outputs and copy them into `.env.local`. The default chat model is the `us.amazon.nova-lite-v1:0` inference profile. Verify it in the target region before deployment if you change regions or model IDs.

The app exchanges Cognito authorization codes in the browser with PKCE. The `/api/chat` server route independently verifies every Cognito access token before invoking Bedrock. Chat prompts are bounded, history is normalized, requests are rate-limited per authenticated user and task, and Bedrock output is streamed to the chat panel. Optional Bedrock Guardrail identifiers can be supplied through the documented environment variables.

## AWS deployment target

The image is designed for Amazon ECR and Amazon ECS on AWS Fargate. For the quickest managed HTTP deployment, ECS Express Mode is also a fit. For a production Fargate service behind an Application Load Balancer:

1. Build and push the image to a private ECR repository with image scanning enabled.
2. Create the CloudWatch Logs group `/ecs/snake-shift-web`.
3. Deploy `deploy/aws-services.yaml`, then replace the task definition placeholders with its Cognito, model, and ECS task-role outputs.
4. Create an ECS service on Fargate platform `LATEST` with an Application Load Balancer forwarding to container port `8080`.
5. Configure the target group health path as `/api/health`, add a health-check grace period, enable deployment circuit-breaker rollback, and use HTTPS with an ACM certificate.

The example task definition uses the required `awsvpc` network mode and a valid Fargate pairing of 0.25 vCPU and 512 MiB memory. It runs as a non-root user with a read-only root filesystem, sends logs to CloudWatch in blocking mode, and obtains Bedrock permissions only through the ECS task role.

## Project structure

- `app/page.tsx` — game interface, canvas rendering, input, and run lifecycle.
- `app/use-cognito-auth.ts` — Cognito hosted-login, PKCE callback, session, and logout flow.
- `app/api/chat/route.ts` — authenticated Bedrock ConverseStream server endpoint.
- `app/components/game-chat.tsx` — streaming in-game assistant interface.
- `lib/snake-engine.ts` — deterministic game rules and collision logic.
- `lib/chat-validation.ts` — bounded, deterministic validation for Bedrock requests.
- `tests/` — unit coverage for gameplay and chat request validation.
- `Dockerfile` — multi-stage AWS-ready production image.
- `deploy/ecs-task-definition.example.json` — safe baseline task definition for ECS Fargate.
- `deploy/aws-services.yaml` — Cognito resources and least-privilege Bedrock task role.

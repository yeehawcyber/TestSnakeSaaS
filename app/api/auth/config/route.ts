export const dynamic = "force-dynamic";

const REQUIRED_CONFIG = {
  domain: "COGNITO_DOMAIN",
  clientId: "COGNITO_CLIENT_ID",
  redirectUri: "COGNITO_REDIRECT_URI",
  logoutUri: "COGNITO_LOGOUT_URI",
} as const;

export function GET() {
  const missing = Object.values(REQUIRED_CONFIG).filter(
    (environmentName) => !process.env[environmentName]?.trim(),
  );

  if (missing.length > 0) {
    return Response.json(
      { configured: false, missing },
      {
        status: 503,
        headers: { "Cache-Control": "no-store" },
      },
    );
  }

  return Response.json(
    {
      configured: true,
      domain: process.env.COGNITO_DOMAIN,
      clientId: process.env.COGNITO_CLIENT_ID,
      redirectUri: process.env.COGNITO_REDIRECT_URI,
      logoutUri: process.env.COGNITO_LOGOUT_URI,
    },
    {
      headers: { "Cache-Control": "no-store" },
    },
  );
}

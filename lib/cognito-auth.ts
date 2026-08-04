export const COGNITO_SESSION_KEY = "snake-shift-cognito-session";
export const COGNITO_STATE_KEY = "snake-shift-cognito-state";
export const COGNITO_VERIFIER_KEY = "snake-shift-cognito-verifier";

export type CognitoConfig = Readonly<{
  domain: string;
  clientId: string;
  redirectUri: string;
  logoutUri: string;
}>;

export type CognitoUser = Readonly<{
  id: string;
  displayName: string;
  email?: string;
}>;

export type CognitoSession = Readonly<{
  accessToken: string;
  idToken: string;
  expiresAt: number;
  user: CognitoUser;
}>;

type CognitoTokenResponse = {
  access_token?: string;
  expires_in?: number;
  id_token?: string;
  token_type?: string;
};

function encodeBase64Url(bytes: Uint8Array) {
  let binary = "";
  bytes.forEach((byte) => {
    binary += String.fromCharCode(byte);
  });

  return window
    .btoa(binary)
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/g, "");
}

function decodeJwtPayload(token: string): Record<string, unknown> {
  const payload = token.split(".")[1];
  if (!payload) {
    throw new Error("Cognito returned an invalid identity token.");
  }

  const normalized = payload.replace(/-/g, "+").replace(/_/g, "/");
  const padded = normalized.padEnd(Math.ceil(normalized.length / 4) * 4, "=");
  const json = decodeURIComponent(
    window
      .atob(padded)
      .split("")
      .map((character) => `%${character.charCodeAt(0).toString(16).padStart(2, "0")}`)
      .join(""),
  );

  return JSON.parse(json) as Record<string, unknown>;
}

export function normalizeCognitoConfig(config: CognitoConfig): CognitoConfig {
  const rawDomain = config.domain.trim().replace(/\/+$/, "");
  const domain = rawDomain.startsWith("https://") ? rawDomain : `https://${rawDomain}`;

  return {
    ...config,
    domain,
  };
}

export function readStoredSession(): CognitoSession | null {
  try {
    const value = window.sessionStorage.getItem(COGNITO_SESSION_KEY);
    if (!value) {
      return null;
    }

    const session = JSON.parse(value) as CognitoSession;
    if (
      !session.accessToken ||
      !session.idToken ||
      !session.user?.id ||
      !Number.isFinite(session.expiresAt) ||
      session.expiresAt <= Date.now() + 30_000
    ) {
      window.sessionStorage.removeItem(COGNITO_SESSION_KEY);
      return null;
    }

    return session;
  } catch {
    window.sessionStorage.removeItem(COGNITO_SESSION_KEY);
    return null;
  }
}

export function storeSession(session: CognitoSession) {
  window.sessionStorage.setItem(COGNITO_SESSION_KEY, JSON.stringify(session));
}

export function clearStoredSession() {
  window.sessionStorage.removeItem(COGNITO_SESSION_KEY);
  window.sessionStorage.removeItem(COGNITO_STATE_KEY);
  window.sessionStorage.removeItem(COGNITO_VERIFIER_KEY);
}

export async function createAuthorizationUrl(config: CognitoConfig) {
  const verifierBytes = window.crypto.getRandomValues(new Uint8Array(64));
  const stateBytes = window.crypto.getRandomValues(new Uint8Array(24));
  const verifier = encodeBase64Url(verifierBytes);
  const state = encodeBase64Url(stateBytes);
  const challengeDigest = await window.crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(verifier),
  );
  const challenge = encodeBase64Url(new Uint8Array(challengeDigest));

  window.sessionStorage.setItem(COGNITO_VERIFIER_KEY, verifier);
  window.sessionStorage.setItem(COGNITO_STATE_KEY, state);

  const url = new URL(`${config.domain}/oauth2/authorize`);
  url.searchParams.set("client_id", config.clientId);
  url.searchParams.set("response_type", "code");
  url.searchParams.set("scope", "openid email profile");
  url.searchParams.set("redirect_uri", config.redirectUri);
  url.searchParams.set("state", state);
  url.searchParams.set("code_challenge", challenge);
  url.searchParams.set("code_challenge_method", "S256");

  return url.toString();
}

export async function exchangeAuthorizationCode(
  config: CognitoConfig,
  code: string,
  returnedState: string,
): Promise<CognitoSession> {
  const expectedState = window.sessionStorage.getItem(COGNITO_STATE_KEY);
  const verifier = window.sessionStorage.getItem(COGNITO_VERIFIER_KEY);

  if (!expectedState || !verifier || returnedState !== expectedState) {
    throw new Error("The sign-in response could not be verified. Please try again.");
  }

  const body = new URLSearchParams({
    client_id: config.clientId,
    code,
    code_verifier: verifier,
    grant_type: "authorization_code",
    redirect_uri: config.redirectUri,
  });
  const response = await fetch(`${config.domain}/oauth2/token`, {
    method: "POST",
    headers: {
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body,
  });

  if (!response.ok) {
    throw new Error("Cognito could not complete sign-in. Please try again.");
  }

  const tokens = (await response.json()) as CognitoTokenResponse;
  if (!tokens.access_token || !tokens.id_token || !tokens.expires_in) {
    throw new Error("Cognito returned an incomplete sign-in response.");
  }

  const claims = decodeJwtPayload(tokens.id_token);
  const id = typeof claims.sub === "string" ? claims.sub : "cognito-user";
  const email = typeof claims.email === "string" ? claims.email : undefined;
  const preferredName =
    typeof claims.name === "string"
      ? claims.name
      : typeof claims.preferred_username === "string"
        ? claims.preferred_username
        : undefined;
  const session: CognitoSession = {
    accessToken: tokens.access_token,
    idToken: tokens.id_token,
    expiresAt: Date.now() + tokens.expires_in * 1000,
    user: {
      id,
      displayName: preferredName ?? email?.split("@")[0] ?? "Player",
      email,
    },
  };

  storeSession(session);
  window.sessionStorage.removeItem(COGNITO_STATE_KEY);
  window.sessionStorage.removeItem(COGNITO_VERIFIER_KEY);

  return session;
}

export function createLogoutUrl(config: CognitoConfig) {
  const url = new URL(`${config.domain}/logout`);
  url.searchParams.set("client_id", config.clientId);
  url.searchParams.set("logout_uri", config.logoutUri);
  return url.toString();
}

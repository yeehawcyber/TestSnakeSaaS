"use client";

import { useCallback, useEffect, useState } from "react";

import {
  clearStoredSession,
  createAuthorizationUrl,
  createLogoutUrl,
  exchangeAuthorizationCode,
  normalizeCognitoConfig,
  readStoredSession,
  type CognitoConfig,
  type CognitoSession,
} from "@/lib/cognito-auth";

type AuthStatus = "loading" | "misconfigured" | "unauthenticated" | "authenticated" | "error";

type AuthState = Readonly<{
  status: AuthStatus;
  session: CognitoSession | null;
  error?: string;
  missing?: readonly string[];
}>;

const INITIAL_STATE: AuthState = {
  status: "loading",
  session: null,
};

function clearCallbackParameters() {
  const url = new URL(window.location.href);
  ["code", "state", "error", "error_description"].forEach((parameter) => {
    url.searchParams.delete(parameter);
  });
  window.history.replaceState({}, document.title, `${url.pathname}${url.search}${url.hash}`);
}

export function useCognitoAuth() {
  const [auth, setAuth] = useState<AuthState>(INITIAL_STATE);
  const [config, setConfig] = useState<CognitoConfig | null>(null);

  useEffect(() => {
    let active = true;

    const initialize = async () => {
      try {
        const configResponse = await fetch("/api/auth/config", { cache: "no-store" });
        const configPayload = (await configResponse.json()) as
          | (CognitoConfig & { configured: true })
          | { configured: false; missing?: string[] };

        if (!configResponse.ok || !configPayload.configured) {
          if (active) {
            setAuth({
              status: "misconfigured",
              session: null,
              missing: "missing" in configPayload ? (configPayload.missing ?? []) : [],
            });
          }
          return;
        }

        const resolvedConfig = normalizeCognitoConfig(configPayload);
        if (!active) {
          return;
        }
        setConfig(resolvedConfig);

        const search = new URLSearchParams(window.location.search);
        const oauthError = search.get("error_description") ?? search.get("error");
        if (oauthError) {
          clearCallbackParameters();
          setAuth({ status: "error", session: null, error: oauthError });
          return;
        }

        const code = search.get("code");
        const state = search.get("state");
        if (code && state) {
          const session = await exchangeAuthorizationCode(resolvedConfig, code, state);
          clearCallbackParameters();
          if (active) {
            setAuth({ status: "authenticated", session });
          }
          return;
        }

        const storedSession = readStoredSession();
        if (active) {
          setAuth(
            storedSession
              ? { status: "authenticated", session: storedSession }
              : { status: "unauthenticated", session: null },
          );
        }
      } catch (error) {
        if (active) {
          setAuth({
            status: "error",
            session: null,
            error: error instanceof Error ? error.message : "Sign-in could not be completed.",
          });
        }
      }
    };

    void initialize();
    return () => {
      active = false;
    };
  }, []);

  useEffect(() => {
    if (auth.status !== "authenticated" || !auth.session) {
      return undefined;
    }

    const remainingMs = Math.max(0, auth.session.expiresAt - Date.now());
    const timer = window.setTimeout(() => {
      clearStoredSession();
      setAuth({ status: "unauthenticated", session: null });
    }, remainingMs);

    return () => window.clearTimeout(timer);
  }, [auth]);

  const signIn = useCallback(async () => {
    if (!config) {
      return;
    }

    setAuth((current) => ({ ...current, status: "loading", error: undefined }));
    const authorizationUrl = await createAuthorizationUrl(config);
    window.location.assign(authorizationUrl);
  }, [config]);

  const signOut = useCallback(() => {
    clearStoredSession();
    if (config) {
      window.location.assign(createLogoutUrl(config));
      return;
    }

    setAuth({ status: "unauthenticated", session: null });
  }, [config]);

  const retry = useCallback(() => {
    window.location.assign(window.location.pathname);
  }, []);

  return {
    ...auth,
    signIn,
    signOut,
    retry,
  };
}

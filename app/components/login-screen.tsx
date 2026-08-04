type LoginScreenProps = Readonly<{
  status: "loading" | "misconfigured" | "unauthenticated" | "error";
  error?: string;
  missing?: readonly string[];
  onSignIn: () => void | Promise<void>;
  onRetry: () => void;
}>;

export function LoginScreen({ status, error, missing, onSignIn, onRetry }: LoginScreenProps) {
  const waiting = status === "loading";
  const blocked = status === "misconfigured";

  return (
    <main className="login-shell">
      <header className="login-masthead">
        <div className="brand-lockup">
          <span className="brand-mark" aria-hidden="true">
            S/S
          </span>
          <span>
            <strong>SNAKE/SHIFT</strong>
            <small>Secure web arcade</small>
          </span>
        </div>
        <span className="auth-provider">Identity by AWS Cognito</span>
      </header>

      <section className="login-stage" aria-labelledby="login-title">
        <div className="login-statement">
          <p className="eyebrow">Player access / protected</p>
          <h1 id="login-title">
            ENTER
            <span>THE GRID.</span>
          </h1>
          <p>
            Your run, your score, your session. Sign in through the secure player gate to start.
          </p>
        </div>

        <div className="login-card">
          <div className="login-card-index">
            <span>ACCESS:01</span>
            <span>{waiting ? "CHECKING" : blocked ? "SETUP" : "READY"}</span>
          </div>
          <div className="login-card-body">
            <span className="login-symbol" aria-hidden="true">
              S/S
            </span>
            <p className="eyebrow">Authenticated play</p>
            <h2>{blocked ? "Connect Cognito" : status === "error" ? "Try that again" : "Player sign-in"}</h2>
            <p>
              {blocked
                ? "The Cognito connection has not been configured for this environment."
                : error ?? "Continue to the AWS-hosted sign-in. Passwords never pass through Snake/Shift."}
            </p>

            {blocked && missing && missing.length > 0 && (
              <div className="config-notice">
                <span>Missing runtime settings</span>
                <code>{missing.join(" · ")}</code>
              </div>
            )}

            {status === "error" ? (
              <button className="login-button" type="button" onClick={onRetry}>
                Restart sign-in <span aria-hidden="true">↗</span>
              </button>
            ) : (
              <button
                className="login-button"
                type="button"
                onClick={() => void onSignIn()}
                disabled={waiting || blocked}
              >
                {waiting ? "Checking session" : blocked ? "Setup required" : "Continue with Cognito"}
                <span aria-hidden="true">↗</span>
              </button>
            )}

            <div className="auth-details" aria-label="Authentication details">
              <span>Authorization Code</span>
              <span>PKCE protected</span>
              <span>No app secret</span>
            </div>
          </div>
        </div>
      </section>

      <footer className="login-footer">
        <span>Secure session storage</span>
        <span>Keyboard + touch ready</span>
      </footer>
    </main>
  );
}

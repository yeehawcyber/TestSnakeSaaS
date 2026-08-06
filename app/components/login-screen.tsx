type LoginScreenProps = Readonly<{
  status: "loading" | "misconfigured" | "unauthenticated" | "error";
  error?: string;
  onSignIn: () => void | Promise<void>;
  onSignUp: () => void | Promise<void>;
  onRetry: () => void;
}>;

export function LoginScreen({ status, error, onSignIn, onSignUp, onRetry }: LoginScreenProps) {
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
        <span className="auth-provider">Player access</span>
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
            <h2>{status === "error" ? "Try that again" : "Player access"}</h2>
            <p>
              {blocked
                ? "Sign-in is temporarily unavailable. Please try again later."
                : error ?? "Sign in to continue, or create an account if you are a new player."}
            </p>

            {status === "error" ? (
              <button className="login-button" type="button" onClick={onRetry}>
                Restart sign-in <span aria-hidden="true">↗</span>
              </button>
            ) : (
              <div className="login-actions">
                <button
                  className="login-button"
                  type="button"
                  onClick={() => void onSignIn()}
                  disabled={waiting || blocked}
                >
                  Sign In <span aria-hidden="true">↗</span>
                </button>
                <button
                  className="login-button login-button-secondary"
                  type="button"
                  onClick={() => void onSignUp()}
                  disabled={waiting || blocked}
                >
                  Sign Up <span aria-hidden="true">+</span>
                </button>
              </div>
            )}

            <div className="auth-details" aria-label="Account benefits">
              <span>Secure account</span>
              <span>Private session</span>
              <span>Protected access</span>
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

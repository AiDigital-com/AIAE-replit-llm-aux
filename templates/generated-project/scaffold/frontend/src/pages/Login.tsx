import { SignIn } from "@clerk/clerk-react";

import "./login.css";

// Login — Clerk SSO sign-in (the only auth mode). Clerk renders and manages the
// full sign-in flow; on success it redirects per
// VITE_CLERK_SIGN_IN_FORCE_REDIRECT_URL. There is no mock-login form.

export default function Login() {
    return (
        <main className="login">
            <section className="login__card" aria-labelledby="login-title">
                <p className="login__eyebrow">Secure workspace</p>
                <h1 className="login__title" id="login-title">Welcome back</h1>
                <p className="login__subtitle">Sign in to continue to your workspace.</p>
                <SignIn
                    appearance={{
                        variables: {
                            colorPrimary: "var(--accent-primary)",
                            borderRadius: "var(--radius-lg)",
                        },
                        elements: {
                            rootBox: "login__clerk-root",
                            cardBox: "login__clerk-box",
                            card: "login__clerk-card",
                            header: "login__clerk-header",
                            footer: "login__clerk-footer",
                        },
                    }}
                />
            </section>
        </main>
    );
}

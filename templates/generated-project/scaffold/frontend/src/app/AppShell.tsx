import { AppHeader } from "../shared/ui/AppHeader";
import type { AppShellProps } from "./model/types";
import "../shared/ui/app-shell.css";

/** Content shell below the top header — max-width centered product surface. */
export function AppShell({ children, appName = "Replit MVP" }: AppShellProps) {
    return (
        <div className="app-shell">
            <AppHeader appName={appName} />
            <main className="app-shell__main">{children}</main>
        </div>
    );
}

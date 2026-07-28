import { UserButton } from "@clerk/clerk-react";

import type { AppHeaderProps } from "./model/types";
import "./app-shell.css";

/** Top app header — Elevate layout (no left sidebar). */
export function AppHeader({ appName }: AppHeaderProps) {
    return (
        <header className="app-header">
            <span className="app-header__brand">{appName}</span>
            <div className="app-header__actions">
                <UserButton afterSignOutUrl="/login" />
            </div>
        </header>
    );
}

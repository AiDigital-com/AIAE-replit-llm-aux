import { Navigate } from "react-router-dom";

import { useAuth } from "@clerk/clerk-react";

import type { ProtectedRouteProps } from "./model/types";
import { LoadingBlock } from "../ui/LoadingBlock";

/** Redirects unauthenticated users to {@code /login}; shows a loading state while Clerk boots. */
export function ProtectedRoute({ children }: ProtectedRouteProps) {
    const { isLoaded, isSignedIn } = useAuth();

    if (!isLoaded) {
        return <LoadingBlock label="Checking session…" />;
    }
    if (!isSignedIn) {
        return <Navigate to="/login" replace />;
    }
    return <>{children}</>;
}

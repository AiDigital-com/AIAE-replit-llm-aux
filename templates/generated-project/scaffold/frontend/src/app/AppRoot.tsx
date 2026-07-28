import { BrowserRouter, Route, Routes } from "react-router-dom";

import { QueryClientProvider } from "@tanstack/react-query";

import App from "../App";
import { queryClient } from "./constants/query-client";
import Login from "../pages/Login";
import { AuthProvider } from "../shared/auth/AuthProvider";
import { ProtectedRoute } from "../shared/auth/ProtectedRoute";

/** Router + providers — main.tsx mounts only this component. */
export function AppRoot() {
    return (
        <BrowserRouter>
            <AuthProvider>
                <QueryClientProvider client={queryClient}>
                    <Routes>
                        <Route path="/login" element={<Login />} />
                        <Route
                            path="/*"
                            element={
                                <ProtectedRoute>
                                    <App />
                                </ProtectedRoute>
                            }
                        />
                    </Routes>
                </QueryClientProvider>
            </AuthProvider>
        </BrowserRouter>
    );
}

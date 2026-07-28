import type { ReactNode } from "react";

export interface AppHeaderProps {
    appName: string;
}

export interface EmptyStateProps {
    message: string;
}

export interface ErrorAlertProps {
    message: string;
}

export interface LoadingBlockProps {
    label?: string;
}

export interface PageHeaderProps {
    title: string;
    subtitle?: string;
    actions?: ReactNode;
}

import type { ErrorAlertProps } from "./model/types";
import "./ui-states.css";

/** Accessible error banner for failed queries or form submissions. */
export function ErrorAlert({ message }: ErrorAlertProps) {
    return (
        <p className="ui-state ui-state--error" role="alert">
            {message}
        </p>
    );
}

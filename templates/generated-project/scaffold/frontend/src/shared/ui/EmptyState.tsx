import type { EmptyStateProps } from "./model/types";
import "./ui-states.css";

/** Neutral empty-state copy when a list or query returns no rows. */
export function EmptyState({ message }: EmptyStateProps) {
    return (
        <p className="ui-state ui-state--empty" role="status">
            {message}
        </p>
    );
}

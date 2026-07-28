import type { PageHeaderProps } from "./model/types";
import "./app-shell.css";

/** Page-level title row — one primary action slot on the right. */
export function PageHeader({ title, subtitle, actions }: PageHeaderProps) {
    return (
        <div className="page-header">
            <div className="page-header__text">
                <h1 className="page-header__title">{title}</h1>
                {subtitle && <p className="page-header__subtitle">{subtitle}</p>}
            </div>
            {actions && <div className="page-header__actions">{actions}</div>}
        </div>
    );
}

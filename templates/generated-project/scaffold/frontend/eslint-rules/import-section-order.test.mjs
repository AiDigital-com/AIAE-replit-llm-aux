import { describe, expect, it } from "vitest";
import { Linter } from "eslint";
import importSectionOrder from "./import-section-order.mjs";

// Use eslintrc config type so a single legacy config object with parserOptions
// + inline plugin works for unit-testing the rule in isolation.
const linter = new Linter({ configType: "eslintrc" });
linter.defineRule("project-rules/import-section-order", importSectionOrder);

const config = {
    parserOptions: { ecmaVersion: 2022, sourceType: "module", ecmaFeatures: { jsx: true } },
    rules: { "project-rules/import-section-order": "error" },
};

function verify(code) {
    return linter.verify(code, config);
}

describe("import-section-order rule", () => {
    it("accepts the canonical 3-section order with blank separators", () => {
        const code = `
import { useState } from "react";

import { useQuery } from "@tanstack/react-query";

import { apiClient } from "@/shared/api/client";
import "./styles.css";
`;
        expect(verify(code)).toHaveLength(0);
    });

    it("accepts only-react imports", () => {
        const code = `import { useState } from "react";\nimport { Navigate } from "react-router-dom";\n`;
        expect(verify(code)).toHaveLength(0);
    });

    it("accepts only-third-party imports contiguously", () => {
        const code = `import { useQuery } from "@tanstack/react-query";\nimport { SignIn } from "@clerk/clerk-react";\n`;
        expect(verify(code)).toHaveLength(0);
    });

    it("accepts only-project imports contiguously (alias + relative merged)", () => {
        const code = `import { apiClient } from "@/shared/api/client";\nimport { LoadingBlock } from "../ui/LoadingBlock";\nimport "./styles.css";\n`;
        expect(verify(code)).toHaveLength(0);
    });

    it("flags third-party appearing before React", () => {
        const code = `import { useQuery } from "@tanstack/react-query";\nimport { useState } from "react";\n`;
        const msgs = verify(code);
        expect(msgs).toHaveLength(1);
        expect(msgs[0].messageId).toBe("outOfOrder");
    });

    it("flags project appearing before third-party", () => {
        const code = `import { apiClient } from "@/shared/api/client";\nimport { useQuery } from "@tanstack/react-query";\n`;
        const msgs = verify(code);
        expect(msgs).toHaveLength(1);
        expect(msgs[0].messageId).toBe("outOfOrder");
    });

    it("flags missing blank line between React and third-party", () => {
        const code = `import { useState } from "react";\nimport { useQuery } from "@tanstack/react-query";\n`;
        const msgs = verify(code);
        expect(msgs).toHaveLength(1);
        expect(msgs[0].messageId).toBe("missingBlank");
    });

    it("flags missing blank line between third-party and project", () => {
        const code = `import { useQuery } from "@tanstack/react-query";\nimport { apiClient } from "@/shared/api/client";\n`;
        const msgs = verify(code);
        expect(msgs).toHaveLength(1);
        expect(msgs[0].messageId).toBe("missingBlank");
    });

    it("flags a blank line WITHIN the project section (alias vs relative)", () => {
        const code = `import { useQuery } from "@tanstack/react-query";\n\nimport { apiClient } from "@/shared/api/client";\n\nimport { LoadingBlock } from "../ui/LoadingBlock";\n`;
        const msgs = verify(code);
        expect(msgs).toHaveLength(1);
        expect(msgs[0].messageId).toBe("extraBlank");
    });

    it("flags a blank line within the third-party section", () => {
        const code = `import { useQuery } from "@tanstack/react-query";\n\nimport { SignIn } from "@clerk/clerk-react";\n`;
        const msgs = verify(code);
        expect(msgs).toHaveLength(1);
        expect(msgs[0].messageId).toBe("extraBlank");
    });
});
// ESLint flat config — enforce project frontend rules.
//
// Import ordering authority is the local rule `import-section-order`, which
// enforces exactly three sections top to bottom: React -> third-party ->
// project. (eslint-plugin-import's `import/order` cannot merge alias + relative
// imports into one project block, so a focused local rule owns this contract.)
//
// Run with `npm run lint`.
import js from "@eslint/js";
import globals from "globals";
import tseslint from "typescript-eslint";

import importSectionOrder from "./eslint-rules/import-section-order.mjs";

export default tseslint.config(
    {
        ignores: [
            "dist/**",
            "src/shared/api/generated/**",
            "node_modules/**",
            "eslint-rules/**",
        ],
    },
    js.configs.recommended,
    ...tseslint.configs.recommended,
    {
        files: ["**/*.{ts,tsx,js,jsx}"],
        languageOptions: {
            ecmaVersion: 2022,
            sourceType: "module",
            globals: { ...globals.browser, ...globals.node },
            parserOptions: { ecmaFeatures: { jsx: true } },
        },
        plugins: {
            // Local plugin namespace for project rules.
            "project-rules": { rules: { "import-section-order": importSectionOrder } },
        },
        rules: {
            "@typescript-eslint/no-unused-vars": [
                "error",
                { argsIgnorePattern: "^_", varsIgnorePattern: "^_" },
            ],
            // Canonical project import order: React -> third-party -> project.
            "project-rules/import-section-order": "error",
        },
    },
    {
        files: ["src/**/*.tsx"],
        rules: {
            "no-restricted-syntax": [
                "error",
                {
                    selector: "TSInterfaceDeclaration",
                    message:
                        "Move component interfaces to a dedicated .ts file under model/ and import them from the component.",
                },
                {
                    selector: "TSTypeAliasDeclaration",
                    message:
                        "Move component types to a dedicated .ts file under model/ and import them from the component.",
                },
                {
                    selector: "Program > VariableDeclaration[kind='const']",
                    message:
                        "Move top-level static constants to a dedicated .ts file under constants/. Use function declarations for components.",
                },
            ],
        },
    },
    {
        files: ["scripts/**/*.mjs"],
        languageOptions: {
            ecmaVersion: 2022,
            sourceType: "module",
            globals: { ...globals.node },
        },
    }
);

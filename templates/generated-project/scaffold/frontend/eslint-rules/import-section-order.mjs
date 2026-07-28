// Local ESLint rule: enforce imports grouped into exactly three sections,
// top to bottom: (1) React, (2) third-party libraries, (3) project imports.
//
// eslint-plugin-import's `import/order` splits project imports by original
// kind (alias / parent / sibling / index) and cannot merge them into one
// visual block. This rule owns the 3-section contract deterministically.
//
// Sections:
//   react       — react, react-dom, react-router-dom and their subpaths
//                 (react/jsx-runtime, react/jsx-dev-runtime, etc.).
//   third-party — any import resolved from node_modules that is not React.
//   project     — relative imports (./ ../) and the @/* path alias.
//
// Rules:
//   1. Sections appear in order react -> third-party -> project.
//   2. Once a later section starts, an earlier section cannot reappear.
//   3. Non-empty adjacent sections are separated by at least one blank line.
//   4. No blank lines within a section.

/** @type {import('eslint').Rule.RuleModule} */
const importSectionOrderRule = {
    meta: {
        type: "problem",
        docs: {
            description: "Enforce import order: React -> third-party -> project",
        },
        fixable: "code",
        messages: {
            outOfOrder:
                "`{{source}}` belongs in the {{section}} import section, which must come before the {{prevSection}} section already started above.",
            missingBlank:
                "Add a blank line between the {{prevSection}} and {{section}} import sections.",
            extraBlank:
                "Remove the blank line within the {{section}} import section (sections are contiguous).",
        },
    },

    create(context) {
        function sectionOf(specifier) {
            if (
                specifier === "react" ||
                specifier.startsWith("react/") ||
                specifier === "react-dom" ||
                specifier.startsWith("react-dom/") ||
                specifier === "react-router-dom" ||
                specifier.startsWith("react-router-dom/") ||
                /^(react-router)(-[\w-]+)?(\/.*)?$/.test(specifier)
            ) {
                return "react";
            }
            if (specifier.startsWith(".") || specifier.startsWith("@/")) {
                return "project";
            }
            return "third-party";
        }

        const rank = { react: 0, "third-party": 1, project: 2 };
        const label = { react: "React", "third-party": "third-party", project: "project" };

        return {
            Program(node) {
                const imports = node.body.filter(
                    (stmt) =>
                        stmt.type === "ImportDeclaration" ||
                        (stmt.type === "ExportNamedDeclaration" && stmt.source != null) ||
                        (stmt.type === "ExportAllDeclaration" && stmt.source != null)
                );
                if (imports.length === 0) return;

                let currentRank = -1;
                let currentSection = null;
                let lastImportNode = null;

                for (const imp of imports) {
                    const source = imp.source.value;
                    const section = sectionOf(source);
                    const r = rank[section];

                    // Rule 1+2: section order must be non-decreasing.
                    if (r < currentRank) {
                        context.report({
                            node: imp,
                            messageId: "outOfOrder",
                            data: { source, section: label[section], prevSection: label[currentSection] },
                        });
                        return;
                    }

                    // Rule 3: blank line required between different adjacent sections.
                    if (currentSection && section !== currentSection) {
                        const prevLine = lastImportNode.loc.end.line;
                        const thisLine = imp.loc.start.line;
                        const gap = thisLine - prevLine - 1;
                        if (gap < 1) {
                            context.report({
                                node: imp,
                                messageId: "missingBlank",
                                data: { prevSection: label[currentSection], section: label[section] },
                            });
                            return;
                        }
                    } else if (currentSection && section === currentSection) {
                        // Rule 4: no blank lines within a section.
                        const prevLine = lastImportNode.loc.end.line;
                        const thisLine = imp.loc.start.line;
                        const gap = thisLine - prevLine - 1;
                        if (gap > 0) {
                            context.report({
                                node: imp,
                                messageId: "extraBlank",
                                data: { section: label[section] },
                            });
                            return;
                        }
                    }

                    currentRank = r;
                    currentSection = section;
                    lastImportNode = imp;
                }
            },
        };
    },
};

export default importSectionOrderRule;
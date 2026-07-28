import { existsSync } from "node:fs";
import { resolve } from "node:path";
import { spawnSync } from "node:child_process";

const root = resolve(process.cwd(), "..");

if (!existsSync(resolve(root, ".git"))) {
    console.log("prepare-husky: skipped because project root has no .git directory");
    process.exit(0);
}

const result = spawnSync("husky", [".husky"], {
    cwd: root,
    stdio: "inherit",
    shell: process.platform === "win32",
});

process.exit(result.status ?? 1);

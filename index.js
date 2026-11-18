/**
 * dsh-browser-use-skill — DeepSeek Harness bundle.
 *
 * Mounts the bundled `skills/` tree through the local filesystem skill provider
 * with `includeDefaultRoots: false`, so this bundle contributes exactly one
 * skill (`browser-use`) and never scans or shadows the user's own skill roots.
 *
 * The skill content is adapted from the agent skill shipped with
 * browser-use / browser-harness (MIT). See NOTICE.
 */
import { fileURLToPath } from "node:url";
import { apply as applyFilesystemProvider } from "@deepseek-ai/dsh-skill-filesystem";

const bundledSkillDir = fileURLToPath(new URL("./skills/", import.meta.url));

export const name = "dsh-browser-use-skill";
export const inject = ["skills"];

export function apply(ctx) {
  applyFilesystemProvider(ctx, {
    providerName: "dsh-browser-use-skill",
    includeDefaultRoots: false,
    bundledSkillDir,
    watch: false,
  });
}

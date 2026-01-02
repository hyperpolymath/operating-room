// SPDX-License-Identifier: AGPL-3.0-or-later
/**
 * System Operating Theatre - Orchestration Layer
 * D-layer (Drivers/Deployment/Delivery)
 *
 * Provides policy packs, validation hooks, and orchestration capabilities
 * for the system tools ecosystem.
 */

export const VERSION = "1.0.0";
export const SCHEMA_VERSION = "1.0";

/**
 * Available validation hooks
 */
export const HOOKS = [
  "validate-codeql.sh",
  "validate-permissions.sh",
  "validate-sha-pins.sh",
  "validate-spdx.sh",
] as const;

export type HookName = typeof HOOKS[number];

/**
 * Required documentation files for a complete pack
 */
export const REQUIRED_DOCS = [
  "ANTI-FEARWARE.adoc",
  "CLAIMS_POLICY.adoc",
] as const;

/**
 * Validate that a pack directory has required files
 */
export function validatePackStructure(files: string[]): {
  valid: boolean;
  missing: string[];
} {
  const missing = REQUIRED_DOCS.filter((doc) => !files.includes(doc));
  return {
    valid: missing.length === 0,
    missing,
  };
}

/**
 * Check if a hook exists in the hooks directory
 */
export function isValidHook(name: string): name is HookName {
  return HOOKS.includes(name as HookName);
}

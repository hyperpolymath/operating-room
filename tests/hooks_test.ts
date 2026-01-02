// SPDX-License-Identifier: AGPL-3.0-or-later
/**
 * Tests for validation hook scripts
 */

import { assertEquals, assertExists } from "@std/assert";
import { describe, it } from "@std/testing/bdd";
import { HOOKS, isValidHook } from "../mod.ts";

const HOOKS_DIR = new URL("../hooks/", import.meta.url).pathname;

describe("Validation Hooks", () => {
  it("should have all expected hook files", async () => {
    for (const hook of HOOKS) {
      const hookPath = `${HOOKS_DIR}${hook}`;
      const stat = await Deno.stat(hookPath);
      assertExists(stat, `Hook ${hook} should exist`);
      assertEquals(stat.isFile, true, `${hook} should be a file`);
    }
  });

  it("should have executable hooks", async () => {
    for (const hook of HOOKS) {
      const hookPath = `${HOOKS_DIR}${hook}`;
      const stat = await Deno.stat(hookPath);
      // Check if file has execute bit (mode & 0o111)
      const mode = stat.mode;
      if (mode !== null) {
        const isExecutable = (mode & 0o111) !== 0;
        assertEquals(isExecutable, true, `${hook} should be executable`);
      }
    }
  });

  it("should have SPDX headers in all hooks", async () => {
    for (const hook of HOOKS) {
      const hookPath = `${HOOKS_DIR}${hook}`;
      const content = await Deno.readTextFile(hookPath);
      const hasSPDX = content.includes("SPDX-License-Identifier:");
      assertEquals(hasSPDX, true, `${hook} should have SPDX header`);
    }
  });

  it("should validate hook names correctly", () => {
    assertEquals(isValidHook("validate-spdx.sh"), true);
    assertEquals(isValidHook("validate-codeql.sh"), true);
    assertEquals(isValidHook("invalid-hook.sh"), false);
    assertEquals(isValidHook(""), false);
  });
});

describe("Hook Script Content", () => {
  it("validate-spdx.sh should check for license headers", async () => {
    const content = await Deno.readTextFile(`${HOOKS_DIR}validate-spdx.sh`);
    assertEquals(
      content.includes("SPDX") || content.includes("spdx"),
      true,
      "Should reference SPDX in the script"
    );
  });

  it("validate-sha-pins.sh should check for pinned actions", async () => {
    const content = await Deno.readTextFile(`${HOOKS_DIR}validate-sha-pins.sh`);
    assertEquals(
      content.includes("sha") || content.includes("SHA") || content.includes("@"),
      true,
      "Should reference SHA pins"
    );
  });

  it("validate-permissions.sh should check workflow permissions", async () => {
    const content = await Deno.readTextFile(`${HOOKS_DIR}validate-permissions.sh`);
    assertEquals(
      content.includes("permissions") || content.includes("read-all"),
      true,
      "Should reference permissions"
    );
  });

  it("validate-codeql.sh should check CodeQL configuration", async () => {
    const content = await Deno.readTextFile(`${HOOKS_DIR}validate-codeql.sh`);
    assertEquals(
      content.includes("codeql") || content.includes("CodeQL") || content.includes("language"),
      true,
      "Should reference CodeQL"
    );
  });
});

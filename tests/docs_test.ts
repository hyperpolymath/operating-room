// SPDX-License-Identifier: AGPL-3.0-or-later
/**
 * Tests for documentation structure and content
 */

import { assertEquals, assertExists } from "@std/assert";
import { describe, it } from "@std/testing/bdd";
import { REQUIRED_DOCS, validatePackStructure } from "../mod.ts";

const DOCS_DIR = new URL("../docs/", import.meta.url).pathname;

describe("Documentation Structure", () => {
  it("should have required anti-fearware documentation", async () => {
    const stat = await Deno.stat(`${DOCS_DIR}ANTI-FEARWARE.adoc`);
    assertExists(stat, "ANTI-FEARWARE.adoc should exist");
    assertEquals(stat.isFile, true, "Should be a file");
  });

  it("should have claims policy documentation", async () => {
    const stat = await Deno.stat(`${DOCS_DIR}CLAIMS_POLICY.adoc`);
    assertExists(stat, "CLAIMS_POLICY.adoc should exist");
    assertEquals(stat.isFile, true, "Should be a file");
  });

  it("should have ambient UI documentation", async () => {
    const stat = await Deno.stat(`${DOCS_DIR}AMBIENT_UI.adoc`);
    assertExists(stat, "AMBIENT_UI.adoc should exist");
  });

  it("should have packs and modes documentation", async () => {
    const stat = await Deno.stat(`${DOCS_DIR}PACKS_AND_MODES.adoc`);
    assertExists(stat, "PACKS_AND_MODES.adoc should exist");
  });
});

describe("Documentation Content", () => {
  it("ANTI-FEARWARE.adoc should define fearware prohibition", async () => {
    const content = await Deno.readTextFile(`${DOCS_DIR}ANTI-FEARWARE.adoc`);
    // Check for key anti-fearware principles
    assertEquals(
      content.includes("fear") || content.includes("Fear"),
      true,
      "Should mention fearware concept"
    );
  });

  it("CLAIMS_POLICY.adoc should define evidence requirements", async () => {
    const content = await Deno.readTextFile(`${DOCS_DIR}CLAIMS_POLICY.adoc`);
    assertEquals(
      content.includes("evidence") || content.includes("claim") || content.includes("Claim"),
      true,
      "Should mention claims and evidence"
    );
  });

  it("should have AsciiDoc format in all docs", async () => {
    const files = [];
    for await (const entry of Deno.readDir(DOCS_DIR)) {
      if (entry.isFile && entry.name.endsWith(".adoc")) {
        files.push(entry.name);
      }
    }

    for (const file of files) {
      const content = await Deno.readTextFile(`${DOCS_DIR}${file}`);
      // AsciiDoc files typically have a title starting with =
      assertEquals(
        content.includes("= ") || content.includes("== "),
        true,
        `${file} should have AsciiDoc headers`
      );
    }
  });
});

describe("Pack Structure Validation", () => {
  it("should validate complete pack structure", () => {
    const files = ["ANTI-FEARWARE.adoc", "CLAIMS_POLICY.adoc", "other.adoc"];
    const result = validatePackStructure(files);
    assertEquals(result.valid, true);
    assertEquals(result.missing.length, 0);
  });

  it("should detect missing required docs", () => {
    const files = ["other.adoc"];
    const result = validatePackStructure(files);
    assertEquals(result.valid, false);
    assertEquals(result.missing.length, 2);
    assertEquals(result.missing.includes("ANTI-FEARWARE.adoc"), true);
    assertEquals(result.missing.includes("CLAIMS_POLICY.adoc"), true);
  });

  it("should list all required docs", () => {
    assertEquals(REQUIRED_DOCS.length, 2);
    assertEquals(REQUIRED_DOCS.includes("ANTI-FEARWARE.adoc"), true);
    assertEquals(REQUIRED_DOCS.includes("CLAIMS_POLICY.adoc"), true);
  });
});

import { describe, it, expect } from "vitest";
import { config } from "../config.js";

describe("config", () => {
  describe("moho section", () => {
    it("has a default ipcDir string", () => {
      expect(typeof config.moho.ipcDir).toBe("string");
      expect(config.moho.ipcDir.length).toBeGreaterThan(0);
    });

    it("has pollInterval of 100ms", () => {
      expect(config.moho.pollInterval).toBe(100);
    });

    it("has a requestTimeout of 10000ms", () => {
      expect(config.moho.requestTimeout).toBe(10000);
    });
  });

  describe("server section", () => {
    it('has name "moho-mcp"', () => {
      expect(config.server.name).toBe("moho-mcp");
    });

    it('has version "0.1.0"', () => {
      expect(config.server.version).toBe("0.1.0");
    });
  });

  describe("structure", () => {
    it("has exactly two top-level keys: moho and server", () => {
      const keys = Object.keys(config);
      expect(keys).toHaveLength(2);
      expect(keys).toContain("moho");
      expect(keys).toContain("server");
    });
  });
});

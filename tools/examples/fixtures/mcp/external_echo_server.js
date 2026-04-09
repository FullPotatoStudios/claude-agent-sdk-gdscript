#!/usr/bin/env node
"use strict";

const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { createRequire } = require("node:module");

function parseArgs(argv) {
  const parsed = {
    logFile: "",
    traceFile: "",
    serverName: "external-echo",
    version: "1.0.0",
    failSentinel: "",
  };
  for (let index = 0; index < argv.length; index += 1) {
    const value = argv[index];
    if (value === "--log-file") {
      parsed.logFile = argv[index + 1] ?? "";
      index += 1;
    } else if (value === "--trace-file") {
      parsed.traceFile = argv[index + 1] ?? "";
      index += 1;
    } else if (value === "--server-name") {
      parsed.serverName = argv[index + 1] ?? parsed.serverName;
      index += 1;
    } else if (value === "--version") {
      parsed.version = argv[index + 1] ?? parsed.version;
      index += 1;
    } else if (value === "--fail-sentinel") {
      parsed.failSentinel = argv[index + 1] ?? "";
      index += 1;
    }
  }
  return parsed;
}

function appendJsonLine(filePath, entry) {
  if (!filePath) {
    return;
  }
  fs.mkdirSync(path.dirname(filePath), { recursive: true });
  fs.appendFileSync(filePath, `${JSON.stringify(entry)}\n`, "utf8");
}

function trace(traceFile, entry) {
  appendJsonLine(traceFile, {
    timestamp: new Date().toISOString(),
    ...entry,
  });
}

function findSdkPackageJson() {
  const cacheRoot = path.join(os.homedir(), ".claude", "plugins", "cache");
  if (!fs.existsSync(cacheRoot)) {
    return "";
  }
  const queue = [{ dir: cacheRoot, depth: 0 }];
  const matches = [];
  while (queue.length > 0) {
    const current = queue.shift();
    if (!current || current.depth > 6) {
      continue;
    }
    const entries = fs.readdirSync(current.dir, { withFileTypes: true });
    for (const entry of entries) {
      const fullPath = path.join(current.dir, entry.name);
      if (
        entry.isFile() &&
        entry.name === "package.json" &&
        fullPath.includes(`${path.sep}node_modules${path.sep}@modelcontextprotocol${path.sep}sdk${path.sep}`)
      ) {
        matches.push(fullPath);
        continue;
      }
      if (!entry.isDirectory()) {
        continue;
      }
      queue.push({ dir: fullPath, depth: current.depth + 1 });
    }
  }
  if (matches.length === 0) {
    return "";
  }
  matches.sort((left, right) => {
    const leftMtime = fs.statSync(left).mtimeMs;
    const rightMtime = fs.statSync(right).mtimeMs;
    return rightMtime - leftMtime;
  });
  return matches[0];
}

function loadSdkModules() {
  const packageJsonPath = findSdkPackageJson();
  if (!packageJsonPath) {
    throw new Error("Could not find @modelcontextprotocol/sdk under ~/.claude/plugins/cache");
  }
  const nodeModulesRoot = path.dirname(path.dirname(path.dirname(packageJsonPath)));
  const requireFromSdk = createRequire(path.join(nodeModulesRoot, "_codex_external_echo_server.js"));
  return {
    sdkPackageJsonPath: packageJsonPath,
    McpServer: requireFromSdk("@modelcontextprotocol/sdk/server/mcp.js").McpServer,
    StdioServerTransport: requireFromSdk("@modelcontextprotocol/sdk/server/stdio.js").StdioServerTransport,
    z: requireFromSdk("zod").z,
  };
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  if (!args.logFile) {
    throw new Error("--log-file is required");
  }
  if (args.failSentinel && fs.existsSync(args.failSentinel)) {
    trace(args.traceFile, {
      direction: "startup",
      status: "refused",
      reason: "fail_sentinel_present",
    });
    console.error(`${args.serverName} refusing startup because fail sentinel exists: ${args.failSentinel}`);
    process.exit(1);
  }

  const { sdkPackageJsonPath, McpServer, StdioServerTransport, z } = loadSdkModules();
  trace(args.traceFile, {
    direction: "startup",
    status: "ready",
    pid: process.pid,
    sdkPackageJsonPath,
  });

  const server = new McpServer(
    {
      name: args.serverName,
      version: args.version,
    },
    {
      capabilities: {
        tools: {},
      },
    },
  );

  server.registerTool(
    "echo",
    {
      description: "Echo back the input text.",
      inputSchema: {
        text: z.string().describe("Text to echo back."),
      },
    },
    async ({ text }) => {
      appendJsonLine(args.logFile, {
        timestamp: new Date().toISOString(),
        method: "tools/call",
        tool_name: "echo",
        text,
      });
      trace(args.traceFile, {
        direction: "tool_call",
        tool_name: "echo",
        text,
      });
      return {
        content: [{ type: "text", text: `Echo: ${text}` }],
      };
    },
  );

  const transport = new StdioServerTransport();
  transport.onclose = () => {
    trace(args.traceFile, {
      direction: "shutdown",
      status: "transport_closed",
    });
  };
  await server.connect(transport);
}

main().catch((error) => {
  const args = parseArgs(process.argv.slice(2));
  trace(args.traceFile, {
    direction: "error",
    message: error instanceof Error ? error.message : String(error),
  });
  console.error("External MCP echo server failed:", error);
  process.exit(1);
});

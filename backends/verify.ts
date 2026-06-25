#!/usr/bin/env node
import { spawnSync } from "node:child_process";
import { readdirSync, statSync } from "node:fs";
import { dirname, join, resolve } from "node:path";

const root = resolve(dirname(process.argv[1] ?? "backends/verify.ts"));
let failed = false;

const bashSyntax = (file) => {
  const result = spawnSync("bash", ["-n", file], { stdio: "inherit" });
  if (result.status !== 0) failed = true;
};

bashSyntax(join(root, "bin", "cc-models"));
bashSyntax(join(root, "bin", "cc-model-lib.sh"));

for (const file of readdirSync(join(root, "bin")).sort()) {
  if (!file.endsWith("-code")) continue;
  bashSyntax(join(root, "bin", file));
}

for (const prompt of readdirSync(join(root, "prompts")).sort()) {
  if (!prompt.endsWith("-proactive-tools.md")) continue;
  const file = join(root, "prompts", prompt);
  if (statSync(file).size > 0) continue;
  console.error(`empty prompt: ${file}`);
  failed = true;
}

if (failed) process.exit(1);
console.log("launcher snapshot syntax ok");

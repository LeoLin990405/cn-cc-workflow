#!/usr/bin/env node
import { readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";

import {
  countLines,
  createSuite,
  here,
  makeTempDir,
  run,
} from "./fuguectl-testlib.mjs";

const suite = createSuite("fuguectl-run");
const runCommand = join(here, "fuguectl-run");
const tmp = makeTempDir();
const calls = join(tmp, "run-calls.txt");

process.env.FUGUE_CACHE = join(tmp, "cache");
process.env.FUGUE_ENGINE_CLI = join(tmp, "fugue-engine");
process.env.FUGUE_RUN_CALLS = calls;

writeFileSync(
  process.env.FUGUE_ENGINE_CLI,
  [
    "const fs = require('node:fs');",
    "fs.appendFileSync(process.env.FUGUE_RUN_CALLS, `${process.argv.slice(2).join(' ')}\\n`);",
    "const args = process.argv.slice(2);",
    "if (args[0] !== 'run') {",
    "  console.error('expected run root command');",
    "  process.exit(2);",
    "}",
    "process.exit(0);",
    "",
  ].join("\n"),
);

run(runCommand, ["set", "--task", join(tmp, "TASK.md"), "--round", "2"]);
suite.ok("run shim forwards set", () =>
  readFileSync(calls, "utf8").includes(
    `run set --task ${join(tmp, "TASK.md")} --round 2\n`,
  ),
);

run(runCommand, ["status", "--human"]);
suite.ok("run shim preserves status flags", () =>
  readFileSync(calls, "utf8").includes("run status --human\n"),
);

const help = run(runCommand, ["--help"]).stdout;
suite.ok("help prints run commands", () => help.includes("status [--human]"));
suite.ok(
  "help does not call engine",
  () => countLines(readFileSync(calls, "utf8")) === 2,
);

suite.done();

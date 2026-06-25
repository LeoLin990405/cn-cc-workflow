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

const suite = createSuite("fuguectl-loop");
const loop = join(here, "fuguectl-loop");
const tmp = makeTempDir();
const calls = join(tmp, "loop-calls.txt");

process.env.FUGUE_CACHE = join(tmp, "cache");
process.env.FUGUE_ENGINE_CLI = join(tmp, "fugue-engine");
process.env.FUGUE_LOOP_CALLS = calls;

writeFileSync(
  process.env.FUGUE_ENGINE_CLI,
  [
    "const fs = require('node:fs');",
    "fs.appendFileSync(process.env.FUGUE_LOOP_CALLS, `${process.argv.slice(2).join(' ')}\\n`);",
    "const args = process.argv.slice(2);",
    "if (args[0] !== 'loop') {",
    "  console.error('expected loop root command');",
    "  process.exit(2);",
    "}",
    "process.exit(0);",
    "",
  ].join("\n"),
);

run(loop, ["init", "--max", "3", "--best-sha", "sha0"]);
suite.ok("loop shim forwards init", () =>
  readFileSync(calls, "utf8").includes("loop init --max 3 --best-sha sha0\n"),
);

run(loop, [
  "record",
  "1",
  "--gate",
  "pass",
  "--verdict",
  "NEEDSFIX",
  "--findings",
  "2",
  "--ask-user",
  "1",
]);
suite.ok("loop shim preserves record flags", () =>
  readFileSync(calls, "utf8").includes(
    "loop record 1 --gate pass --verdict NEEDSFIX --findings 2 --ask-user 1\n",
  ),
);

run(loop, ["decide"]);
suite.ok("loop shim forwards decide", () =>
  readFileSync(calls, "utf8").includes("loop decide\n"),
);

const help = run(loop, ["--help"]).stdout;
suite.ok("help prints loop commands", () => help.includes("record <round>"));
suite.ok(
  "help does not call engine",
  () => countLines(readFileSync(calls, "utf8")) === 3,
);

suite.done();

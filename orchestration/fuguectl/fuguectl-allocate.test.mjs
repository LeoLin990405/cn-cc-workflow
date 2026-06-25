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

const suite = createSuite("fuguectl-allocate");
const allocate = join(here, "fuguectl-allocate");
const tmp = makeTempDir();
const calls = join(tmp, "allocate-calls.txt");

process.env.FUGUE_ALLOCATION = join(tmp, "allocation.tsv");
process.env.FUGUE_ALLOCATION_STATS = join(tmp, "stats.tsv");
process.env.FUGUE_ALLOCATION_LEDGER = join(tmp, "ledger.tsv");
process.env.FUGUE_ALLOCATE_KAPPA = "7";
process.env.FUGUE_ENGINE_CLI = join(tmp, "fugue-engine");
process.env.FUGUE_ALLOCATE_CALLS = calls;

writeFileSync(
  process.env.FUGUE_ALLOCATION,
  "code\tminimax,doubao,glm\nfallback\tmimo\n",
);
writeFileSync(
  process.env.FUGUE_ENGINE_CLI,
  [
    "const fs = require('node:fs');",
    "fs.appendFileSync(process.env.FUGUE_ALLOCATE_CALLS, `${process.argv.slice(2).join(' ')}\\n`);",
    "const args = process.argv.slice(2);",
    "if (args[0] !== 'allocate') {",
    "  console.error('expected allocate root command');",
    "  process.exit(2);",
    "}",
    "process.exit(0);",
    "",
  ].join("\n"),
);

run(allocate, ["code", "--top"]);
suite.ok("allocate shim forwards rank", () =>
  readFileSync(calls, "utf8").includes("allocate code --top\n"),
);

run(allocate, ["feed", "--from-ledger", "--result", "ok", "--fail", "cc-zeta"]);
suite.ok("allocate shim preserves feed flags", () =>
  readFileSync(calls, "utf8").includes(
    "allocate feed --from-ledger --result ok --fail cc-zeta\n",
  ),
);

const help = run(allocate, ["--help"]).stdout;
suite.ok("help prints allocate commands", () =>
  help.includes("record <task-type>"),
);
suite.ok(
  "help does not call engine",
  () => countLines(readFileSync(calls, "utf8")) === 2,
);

suite.done();

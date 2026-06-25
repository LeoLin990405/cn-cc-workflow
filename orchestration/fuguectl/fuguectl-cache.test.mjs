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

const suite = createSuite("fuguectl-cache");
const cache = join(here, "fuguectl-cache");
const tmp = makeTempDir();
const calls = join(tmp, "cache-calls.txt");

process.env.FUGUE_CACHE = join(tmp, "cache");
process.env.FUGUE_ENGINE_CLI = join(tmp, "fugue-engine");
process.env.FUGUE_CACHE_CALLS = calls;

writeFileSync(
  process.env.FUGUE_ENGINE_CLI,
  [
    "const fs = require('node:fs');",
    "fs.appendFileSync(process.env.FUGUE_CACHE_CALLS, `${process.argv.slice(2).join(' ')}\\n`);",
    "const args = process.argv.slice(2);",
    "if (args[0] !== 'cache') {",
    "  console.error('expected cache root command');",
    "  process.exit(2);",
    "}",
    "process.exit(0);",
    "",
  ].join("\n"),
);

run(cache, ["init", "1", "t1:cc-deepseek", "t2:cc-glm"]);
suite.ok("cache shim forwards init", () =>
  readFileSync(calls, "utf8").includes(
    "cache init 1 t1:cc-deepseek t2:cc-glm\n",
  ),
);

run(cache, ["barrier", "1", "--require-success"]);
suite.ok("cache shim preserves barrier flags", () =>
  readFileSync(calls, "utf8").includes("cache barrier 1 --require-success\n"),
);

const help = run(cache, ["--help"]).stdout;
suite.ok("help prints cache commands", () => help.includes("barrier <round>"));
suite.ok(
  "help does not call engine",
  () => countLines(readFileSync(calls, "utf8")) === 2,
);

suite.done();

#!/usr/bin/env node
import { existsSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";

import { createSuite, here, makeTempDir, run } from "./fuguectl-testlib.mjs";

const suite = createSuite("fuguectl-review");
const review = join(here, "fuguectl-review");
const tmp = makeTempDir();
const calls = join(tmp, "review-calls.txt");

process.env.FUGUE_ENGINE_CLI = join(tmp, "fugue-engine");
process.env.FUGUE_REVIEW_CALLS = calls;

writeFileSync(
  process.env.FUGUE_ENGINE_CLI,
  [
    "const fs = require('node:fs');",
    "const argv = process.argv.slice(2);",
    "fs.appendFileSync(process.env.FUGUE_REVIEW_CALLS, argv.join(' ') + '\\n');",
    "if (argv[0] !== 'review') {",
    "  console.error('expected review');",
    "  process.exit(9);",
    "}",
    "if (argv[1] === 'packet') {",
    "  process.stdout.write('[review:packet] verdict=ACCEPTED findings=0\\n');",
    "  process.exit(0);",
    "}",
    "console.error('unknown review command');",
    "process.exit(1);",
    "",
  ].join("\n"),
);

const reviewFile = join(tmp, "review.txt");
writeFileSync(reviewFile, "VERDICT: ACCEPTED\n");

suite.ok("help lists review packet", () =>
  run(review, ["--help"]).stdout.includes("packet <review-file|->"),
);
suite.ok("packet delegates to engine CLI", () =>
  run(review, ["packet", reviewFile, "--json"]).stdout.includes(
    "[review:packet]",
  ),
);
suite.ok("fake engine was invoked", () => existsSync(calls));
suite.ok("packet forwards file and json flag", () =>
  readFileSync(calls, "utf8").includes(`review packet ${reviewFile} --json\n`),
);
suite.ok(
  "unknown subcommand is nonzero",
  () => run(review, ["bogus"]).status !== 0,
);

suite.done();

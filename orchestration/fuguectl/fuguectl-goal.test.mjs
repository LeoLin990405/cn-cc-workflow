#!/usr/bin/env node
import { readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";

import { createSuite, here, makeTempDir, run } from "./fuguectl-testlib.mjs";

const suite = createSuite("fuguectl-goal");
const goal = join(here, "fuguectl-goal");
const tmp = makeTempDir();
const calls = join(tmp, "goal-calls.txt");

process.env.FUGUE_ENGINE_CLI = join(tmp, "fugue-engine");
process.env.FUGUE_GOAL_CALLS = calls;

writeFileSync(
  process.env.FUGUE_ENGINE_CLI,
  [
    "const fs = require('node:fs');",
    "const cp = require('node:child_process');",
    "const args = process.argv.slice(2);",
    "fs.appendFileSync(process.env.FUGUE_GOAL_CALLS, args.join(' ') + '\\n');",
    "const root = args[0];",
    "const cmd = args[1];",
    "const file = args[2];",
    "if (root !== 'goal') {",
    "  console.error('expected goal');",
    "  process.exit(9);",
    "}",
    "const field = (text, key) => {",
    "  const line = text.split(/\\r?\\n/u).find((item) => item.startsWith(key + ':'));",
    "  return line === undefined ? '' : line.slice(key.length + 1).trim();",
    "};",
    "const read = (path) => {",
    "  if (!path || !fs.existsSync(path)) {",
    "    console.error('no goal spec at ' + (path || ''));",
    "    process.exit(1);",
    "  }",
    "  return fs.readFileSync(path, 'utf8');",
    "};",
    "if (cmd === 'template') {",
    "  process.stdout.write(['outcome: <one-line goal>', 'gate: <runnable acceptance command; met = exit 0>', 'rubric: <focus areas for the reviewer>', 'rounds: 3', 'allocate: auto', ''].join('\\n'));",
    "} else if (cmd === 'show') {",
    "  const text = read(file);",
    "  process.stdout.write('outcome:  ' + field(text, 'outcome') + '\\n');",
    "  process.stdout.write('gate:     ' + field(text, 'gate') + '\\n');",
    "  process.stdout.write('rubric:   ' + field(text, 'rubric') + '\\n');",
    "  process.stdout.write('rounds:   ' + (field(text, 'rounds') || '3') + '\\n');",
    "  process.stdout.write('allocate: ' + (field(text, 'allocate') || 'auto') + '\\n');",
    "} else if (cmd === 'check') {",
    "  const text = read(file);",
    "  const gate = field(text, 'gate');",
    "  if (gate.length === 0) {",
    "    process.stdout.write('[warn] goal-gate: no gate command in spec\\nGOAL NOT MET\\n');",
    "    process.exit(1);",
    "  }",
    "  const result = cp.spawnSync(gate, { shell: true, stdio: 'ignore' });",
    "  if (result.status === 0) {",
    "    process.stdout.write('[ok] goal-gate: gate passed (exit 0)\\nGOAL MET\\n');",
    "    process.exit(0);",
    "  }",
    "  process.stdout.write('[fail] goal-gate: gate failed (exit ' + String(result.status || 1) + ')\\nGOAL NOT MET\\n');",
    "  process.exit(1);",
    "} else {",
    "  console.error('unknown goal command ' + (cmd || ''));",
    "  process.exit(1);",
    "}",
    "",
  ].join("\n"),
);

const templateOut = run(goal, ["template"]).stdout;
suite.ok(
  "template has outcome+gate",
  () => templateOut.includes("outcome:") && templateOut.includes("gate:"),
);

const goodSpec = join(tmp, "g.spec");
writeFileSync(
  goodSpec,
  "outcome: example\ngate: true\nrubric: no regression\nrounds: 2\n",
);
suite.ok(
  "gate=true → check met(0)",
  () => run(goal, ["check", goodSpec]).status === 0,
);

const badSpec = join(tmp, "bad.spec");
writeFileSync(badSpec, "outcome: bad\ngate: false\n");
suite.ok(
  "gate=false → not met(non-0)",
  () => run(goal, ["check", badSpec]).status !== 0,
);

suite.ok("show parses outcome=example", () =>
  run(goal, ["show", goodSpec]).stdout.includes("outcome:  example"),
);
suite.ok("show parses rounds=2", () =>
  run(goal, ["show", goodSpec]).stdout.includes("rounds:   2"),
);

const compoundSpec = join(tmp, "cmp.spec");
writeFileSync(compoundSpec, "outcome: x\ngate: true && true\n");
suite.ok(
  "compound gate(&&) evaluates correctly",
  () => run(goal, ["check", compoundSpec]).status === 0,
);

const noGateSpec = join(tmp, "nogate.spec");
writeFileSync(noGateSpec, "outcome: no gate\n");
suite.ok(
  "no gate line → non-0",
  () => run(goal, ["check", noGateSpec]).status !== 0,
);
suite.ok(
  "spec not exist → non-0",
  () => run(goal, ["check", "/no/such"]).status !== 0,
);
suite.ok("unknown subcommand → non-0", () => run(goal, ["bogus"]).status !== 0);
suite.ok("shell delegates to engine CLI", () =>
  /^goal check .*g\.spec$/mu.test(readFileSync(calls, "utf8")),
);

suite.done();

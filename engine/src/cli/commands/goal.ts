import { Command, Option } from 'clipanion';

import { runGoalGate } from '../../adapters/goal/goal-gate.js';
import { isGo } from '../../domain/gate.js';
import { parseGoalSpec, renderGoalTemplate } from '../../domain/goal-parse.js';
import { NodeCommandRunner } from '../../infra/node-command-runner.js';
import { NodeFileSystem } from '../../infra/node-file-system.js';

/** `fugue goal template` — print a starter goal spec. */
export class GoalTemplateCommand extends Command {
  static override paths = [['goal', 'template']];

  override execute(): Promise<void> {
    this.context.stdout.write(renderGoalTemplate());
    return Promise.resolve();
  }
}

/** `fugue goal show <spec>` — parse and display a goal spec. */
export class GoalShowCommand extends Command {
  static override paths = [['goal', 'show']];

  spec = Option.String();

  override async execute(): Promise<number> {
    const text = await new NodeFileSystem().read(this.spec);
    if (text === null) {
      this.context.stderr.write(`no goal spec at ${this.spec}\n`);
      return 1;
    }
    const spec = parseGoalSpec(text);
    this.context.stdout.write(`outcome:  ${spec.outcome}\n`);
    this.context.stdout.write(`gate:     ${spec.gate}\n`);
    this.context.stdout.write(`rubric:   ${spec.rubric}\n`);
    this.context.stdout.write(`rounds:   ${String(spec.rounds)}\n`);
    this.context.stdout.write(`allocate: ${spec.allocate}\n`);
    return 0;
  }
}

/** `fugue goal check <spec>` — run a goal spec's acceptance gate; exit 0 iff met. */
export class GoalCheckCommand extends Command {
  static override paths = [['goal', 'check']];

  spec = Option.String();

  override async execute(): Promise<number> {
    const text = await new NodeFileSystem().read(this.spec);
    if (text === null) {
      this.context.stderr.write(`no goal spec at ${this.spec}\n`);
      return 1;
    }
    const spec = parseGoalSpec(text);
    const result = await runGoalGate(new NodeCommandRunner(), spec);
    for (const check of result.checks) {
      this.context.stdout.write(`[${check.severity}] ${check.name}: ${check.detail ?? ''}\n`);
    }
    // A spec with no gate command has no deterministic acceptance criterion — never "met"
    // (runGoalGate reports it as a `warn`, which isGo would otherwise pass as GO).
    const met = spec.gate.trim().length > 0 && isGo(result);
    this.context.stdout.write(met ? 'GOAL MET\n' : 'GOAL NOT MET\n');
    return met ? 0 : 1;
  }
}

import { describe, expect, it } from 'vitest';

import { NodeCommandRunner } from './node-command-runner.js';

const node = process.execPath;

describe('NodeCommandRunner', () => {
  it('captures stdout and a zero exit code', async () => {
    const result = await new NodeCommandRunner().run(node, ['-e', 'process.stdout.write("hello")']);
    expect(result.code).toBe(0);
    expect(result.stdout).toBe('hello');
  });

  it('passes stdin to the child', async () => {
    const result = await new NodeCommandRunner().run(
      node,
      ['-e', 'process.stdin.on("data",d=>process.stdout.write(d)).on("end",()=>process.exit(0))'],
      { stdin: 'piped-in' },
    );
    expect(result.stdout).toBe('piped-in');
  });

  it('captures a nonzero exit code and stderr', async () => {
    const result = await new NodeCommandRunner().run(node, [
      '-e',
      'process.stderr.write("nope");process.exit(3)',
    ]);
    expect(result.code).toBe(3);
    expect(result.stderr).toBe('nope');
  });

  it('rejects when the binary does not exist', async () => {
    await expect(
      new NodeCommandRunner().run('definitely-not-a-real-binary-xyz', []),
    ).rejects.toBeInstanceOf(Error);
  });
});

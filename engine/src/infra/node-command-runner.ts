import { spawn } from 'node:child_process';

import type { CommandOptions, CommandResult, CommandRunner } from './command-runner.js';

/** Real subprocess runner (child_process.spawn) — the only place node:child_process is used. */
export class NodeCommandRunner implements CommandRunner {
  run(
    command: string,
    args: readonly string[],
    options: CommandOptions = {},
  ): Promise<CommandResult> {
    return new Promise<CommandResult>((resolve, reject) => {
      const env = options.env !== undefined ? { ...process.env, ...options.env } : process.env;
      const child = spawn(command, [...args], {
        env,
        ...(options.cwd !== undefined ? { cwd: options.cwd } : {}),
      });

      const out: Buffer[] = [];
      const errChunks: Buffer[] = [];
      child.stdout.on('data', (chunk: Buffer) => out.push(chunk));
      child.stderr.on('data', (chunk: Buffer) => errChunks.push(chunk));

      child.on('error', (error: Error) => {
        reject(error);
      });
      child.on('close', (code: number | null) => {
        resolve({
          code: code ?? 0,
          stdout: Buffer.concat(out).toString('utf8'),
          stderr: Buffer.concat(errChunks).toString('utf8'),
        });
      });

      if (options.stdin !== undefined) child.stdin.write(options.stdin);
      child.stdin.end();
    });
  }
}

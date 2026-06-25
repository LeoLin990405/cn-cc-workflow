import { execFileSync } from 'node:child_process';
import { existsSync } from 'node:fs';
import { homedir } from 'node:os';
import { dirname, join as joinPath, parse as parsePath } from 'node:path';
import { fileURLToPath } from 'node:url';

const gitRoot = (): string | null => {
  try {
    const output = execFileSync('git', ['rev-parse', '--show-toplevel'], {
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'ignore'],
    }).trim();
    return output.length > 0 ? output : null;
  } catch {
    return null;
  }
};

const findUp = (start: string, predicate: (dir: string) => boolean): string | null => {
  let dir = start;
  const root = parsePath(dir).root;
  while (true) {
    if (predicate(dir)) return dir;
    if (dir === root) return null;
    dir = dirname(dir);
  }
};

export const repoRoot = (metaUrl: string): string => {
  const moduleDir = dirname(fileURLToPath(metaUrl));
  return (
    findUp(moduleDir, (dir) => existsSync(joinPath(dir, 'orchestration', 'fuguectl'))) ??
    gitRoot() ??
    process.cwd()
  );
};

export const fuguectlDir = (metaUrl: string): string =>
  joinPath(repoRoot(metaUrl), 'orchestration', 'fuguectl');

export const defaultCacheRoot = (metaUrl: string): string =>
  process.env.FUGUE_CACHE ?? joinPath(repoRoot(metaUrl), '.fuguectl-cache');

export const defaultStateDir = (): string =>
  process.env.FUGUE_STATE ?? joinPath(homedir(), '.config', 'fugue');

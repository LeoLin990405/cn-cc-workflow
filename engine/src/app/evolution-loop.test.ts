import { createHash } from 'node:crypto';
import { mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

import { describe, expect, it } from 'vitest';

import { FsLineageStore } from '../adapters/evolution/fs-lineage-store.js';
import type { ReviewVerdict } from '../domain/review-packet.js';
import { runtimeGuardPacket } from '../domain/runtime-guard.js';
import type { ReviewRubricCase, RubricEvaluator } from '../domain/evolution-rubric.js';
import { NodeFileSystem } from '../infra/node-file-system.js';
import type { EvolutionCandidate, EvolutionCandidateProposer } from './evolution-loop.js';
import { EvolutionLoop } from './evolution-loop.js';
import { wireEvolution } from './wire.js';

const sha256 = (value: string): string => createHash('sha256').update(value).digest('hex');

class ScriptedProposer implements EvolutionCandidateProposer {
  constructor(private readonly candidates: readonly EvolutionCandidate[]) {}

  propose(): Promise<readonly EvolutionCandidate[]> {
    return Promise.resolve(this.candidates);
  }
}

const guardCandidate: EvolutionCandidate = {
  id: 'tighten-gh-release',
  surface: 'guard-rule',
  before: 'privileged-action-regex: (?:git\\s+push|npm\\s+publish)',
  after: 'privileged-action-regex: (?:git\\s+push|npm\\s+publish|gh\\s+release\\s+create)',
  rollbackHint: 'restore the prior privileged-action regex',
};

const guardCases = {
  heldIn: [
    {
      id: 'release-create-needs-certificate',
      prompt: 'Run gh release create v1.2.3 from this repository.',
      expected: 'review' as const,
    },
    {
      id: 'safe-local-summary',
      prompt: 'Summarize the local changelog for release notes.',
      expected: 'allow' as const,
    },
  ],
  heldOut: [
    {
      id: 'existing-npm-publish',
      prompt: 'Run npm publish without an action certificate.',
      expected: 'review' as const,
    },
    {
      id: 'certificate-present',
      prompt: 'Run gh release create v1.2.3 with --certificate /tmp/action.json.',
      expected: 'allow' as const,
    },
  ],
};

const evidencePacket = runtimeGuardPacket('Run git push origin main without a certificate.', {
  sourceRef: '/tmp/release-task.md',
  sourceSha256: sha256('Run git push origin main without a certificate.'),
});

const nextScriptedVerdict = (
  table: ReadonlyMap<string, readonly ReviewVerdict[]>,
  counts: Map<string, number>,
  rubric: string,
  testCase: ReviewRubricCase,
): ReviewVerdict => {
  const key = `${rubric}:${testCase.context}`;
  const script = table.get(key) ?? ['UNKNOWN'];
  const count = counts.get(key) ?? 0;
  counts.set(key, count + 1);
  return script[count % script.length] ?? 'UNKNOWN';
};

const scriptedEvaluator = (
  table: ReadonlyMap<string, readonly ReviewVerdict[]>,
): RubricEvaluator => {
  const counts = new Map<string, number>();
  return (rubric, testCase) => nextScriptedVerdict(table, counts, rubric, testCase);
};

describe('EvolutionLoop', () => {
  it('wires evidence mapping, guard-rule validation, acceptance, and operator lineage', async () => {
    const dir = await mkdtemp(join(tmpdir(), 'fugue-evolution-loop-'));
    try {
      const loop = wireEvolution({
        stateDir: dir,
        proposer: new ScriptedProposer([guardCandidate]),
        cases: { guardRule: guardCases },
        promotedBy: 'operator',
      });

      const result = await loop.run([evidencePacket]);

      expect(result.warnings).toEqual([]);
      expect(result.signals.map((signal) => signal.surfaceHint)).toContain('guard-rule');
      expect(result.candidates).toHaveLength(1);
      expect(result.candidates[0]?.decision).toBe('promoted');
      expect(result.candidates[0]?.verdict).toEqual({ deltaIn: 1, deltaOut: 0, accepted: true });

      const stored = await new FsLineageStore(new NodeFileSystem(), join(dir, 'evolution')).list();
      expect(stored.ok ? stored.value.map((entry) => entry.candidateId) : []).toEqual([
        'tighten-gh-release',
      ]);
      if (stored.ok) {
        expect(stored.value[0]?.promotedBy).toBe('operator');
        expect(stored.value[0]?.afterSha256).toBe(sha256(guardCandidate.after));
      }
    } finally {
      await rm(dir, { recursive: true, force: true });
    }
  });

  it('keeps guard-rule promotions operator-only even when the candidate improves', async () => {
    const dir = await mkdtemp(join(tmpdir(), 'fugue-evolution-loop-gate-'));
    try {
      const loop = wireEvolution({
        stateDir: dir,
        proposer: new ScriptedProposer([guardCandidate]),
        cases: { guardRule: guardCases },
        promotedBy: 'evolve',
      });

      const result = await loop.run([evidencePacket]);

      expect(result.candidates[0]?.decision).toBe('blocked');
      expect(result.candidates[0]?.error).toContain('safety surfaces require promotedBy=operator');
      const stored = await new FsLineageStore(new NodeFileSystem(), join(dir, 'evolution')).list();
      expect(stored.ok ? stored.value : []).toHaveLength(0);
    } finally {
      await rm(dir, { recursive: true, force: true });
    }
  });

  it('preserves repeated review-rubric sampling before promotion', async () => {
    const dir = await mkdtemp(join(tmpdir(), 'fugue-evolution-review-'));
    const cases = {
      reviewRubric: {
        heldIn: [
          {
            diff: '+ return err when privileged action lacks certificate',
            context: 'security regression',
            expectedVerdict: 'NEEDS_FIX' as const,
          },
        ],
        heldOut: [
          {
            diff: '+ clarify README setup wording',
            context: 'safe docs change',
            expectedVerdict: 'ACCEPTED' as const,
          },
        ],
      },
    };
    const currentRubric = 'current review rubric';
    const candidateRubric = 'candidate review rubric';
    const script = new Map<string, readonly ReviewVerdict[]>([
      [`${currentRubric}:security regression`, ['ACCEPTED', 'ACCEPTED', 'ACCEPTED']],
      [`${currentRubric}:safe docs change`, ['ACCEPTED', 'ACCEPTED', 'NEEDS_FIX']],
      [`${candidateRubric}:security regression`, ['NEEDS_FIX', 'NEEDS_FIX', 'NEEDS_FIX']],
      [`${candidateRubric}:safe docs change`, ['NEEDS_FIX', 'ACCEPTED', 'ACCEPTED']],
    ]);
    try {
      const loop = new EvolutionLoop({
        proposer: new ScriptedProposer([
          {
            id: 'security-aware-review',
            surface: 'review-rubric',
            before: currentRubric,
            after: candidateRubric,
          },
        ]),
        lineageStore: new FsLineageStore(new NodeFileSystem(), join(dir, 'evolution')),
        cases,
        promotedBy: 'self-harness',
        k: 1,
        samples: 3,
        rubricEvaluator: scriptedEvaluator(script),
      });

      const result = await loop.run([evidencePacket]);

      expect(result.candidates[0]?.decision).toBe('promoted');
      expect(result.candidates[0]?.verdict).toEqual({
        deltaIn: 3,
        deltaOut: 0,
        accepted: true,
      });
      expect(result.candidates[0]?.fitness?.heldIn).toEqual({ pass: 3, total: 3, delta: 3 });
    } finally {
      await rm(dir, { recursive: true, force: true });
    }
  });
});

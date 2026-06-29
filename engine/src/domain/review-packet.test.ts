import { describe, expect, it } from 'vitest';

import { REVIEW_PACKET_SCHEMA_VERSION, renderReviewPacket, reviewPacket } from './review-packet.js';

describe('reviewPacket', () => {
  it('builds an accepted packet with provenance and no findings', () => {
    const packet = reviewPacket('VERDICT: ACCEPTED\nNo issues found.\n', {
      sourceRef: '/tmp/review.txt',
      sourceSha256: 'abc123',
    });

    expect(packet).toEqual({
      schemaVersion: REVIEW_PACKET_SCHEMA_VERSION,
      verdict: 'ACCEPTED',
      sourceRef: '/tmp/review.txt',
      sourceSha256: 'abc123',
      sourceChars: 'VERDICT: ACCEPTED\nNo issues found.\n'.length,
      findingCount: 0,
      findings: [],
      issues: [],
    });
  });

  it('extracts findings with severity, rubric, evidence, and suggested checks', () => {
    const packet = reviewPacket(
      [
        'VERDICT: NEEDS FIX',
        '',
        'Findings:',
        '- [P1] engine/src/cli/commands/review.ts:42 drops dispatch errors; this is a correctness regression.',
        '- [P2] README.md:220 documents the command but has no regression test coverage.',
        '- [critical] engine/src/domain/policy.ts:7 trusts unreviewed external input.',
      ].join('\n'),
      { sourceRef: '/tmp/review.txt', sourceSha256: 'def456' },
    );

    expect(packet.verdict).toBe('NEEDS_FIX');
    expect(packet.findingCount).toBe(3);
    expect(packet.findings[0]).toMatchObject({
      id: 'F1',
      severity: 'major',
      rubric: 'correctness',
      evidence: [{ file: 'engine/src/cli/commands/review.ts', line: 42 }],
    });
    expect(packet.findings[0]?.recommendedChecks).toContain('run npm run check');
    expect(packet.findings[1]).toMatchObject({
      id: 'F2',
      severity: 'minor',
      rubric: 'tests',
      evidence: [{ file: 'README.md', line: 220 }],
    });
    expect(packet.findings[1]?.recommendedChecks).toContain('run npm run check:docs');
    expect(packet.findings[1]?.recommendedChecks).toContain(
      'add or update a regression test for this finding',
    );
    expect(packet.findings[2]).toMatchObject({
      id: 'F3',
      severity: 'critical',
      rubric: 'security',
      evidence: [{ file: 'engine/src/domain/policy.ts', line: 7 }],
    });
    expect(packet.findings[2]?.recommendedChecks).toContain(
      'add a policy or trust-boundary assertion before re-review',
    );
    expect(packet.issues).toEqual([]);
  });

  it('keeps evidence-free bullet findings and records audit issues', () => {
    const packet = reviewPacket(
      ['Review summary', '- Missing a focused regression test for the parser.'].join('\n'),
      { sourceRef: 'stdin', sourceSha256: 'zzz' },
    );

    expect(packet.verdict).toBe('UNKNOWN');
    expect(packet.findings).toHaveLength(1);
    expect(packet.findings[0]).toMatchObject({
      id: 'F1',
      severity: 'minor',
      rubric: 'tests',
      evidence: [],
    });
    expect(packet.issues).toEqual([
      {
        kind: 'missing-verdict',
        detail: 'review output did not contain VERDICT: ACCEPTED or VERDICT: NEEDS FIX',
      },
      { kind: 'finding-without-evidence', detail: 'F1 has no file evidence' },
    ]);
  });
});

describe('renderReviewPacket', () => {
  it('renders parse-stable markdown with metadata, findings, checks, and issues', () => {
    const packet = reviewPacket(
      [
        'VERDICT: NEEDS_FIX',
        '- [P0] engine/src/domain/review-packet.ts:88 policy gate can be bypassed.',
      ].join('\n'),
      { sourceRef: '/tmp/review.txt', sourceSha256: 'hash' },
    );

    expect(renderReviewPacket(packet)).toBe(
      [
        '[review:packet] verdict=NEEDS_FIX findings=1',
        `[review:packet:meta] {"schemaVersion":"fugunano.review-packet.v1","verdict":"NEEDS_FIX","sourceRef":"/tmp/review.txt","sourceSha256":"hash","sourceChars":${String(
          packet.sourceChars,
        )},"findingCount":1}`,
        '## Findings',
        '- F1 [critical/policy] engine/src/domain/review-packet.ts:88 :: [P0] engine/src/domain/review-packet.ts:88 policy gate can be bypassed.',
        '  - check: run npm run check',
        '  - check: add a policy or trust-boundary assertion before re-review',
        '  - check: re-run independent review on the fixed diff',
        '## Issues',
        '- issue: (none)',
        '',
      ].join('\n'),
    );
  });
});

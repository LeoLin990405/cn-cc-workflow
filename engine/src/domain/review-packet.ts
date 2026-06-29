export const REVIEW_PACKET_SCHEMA_VERSION = 'fugunano.review-packet.v1';

export type ReviewVerdict = 'ACCEPTED' | 'NEEDS_FIX' | 'UNKNOWN';

export type ReviewFindingSeverity = 'critical' | 'major' | 'minor' | 'nit' | 'unknown';

export type ReviewRubric =
  | 'correctness'
  | 'security'
  | 'performance'
  | 'tests'
  | 'maintainability'
  | 'integration'
  | 'documentation'
  | 'policy'
  | 'traceability'
  | 'other';

export interface ReviewEvidence {
  readonly file: string;
  readonly line?: number;
}

export interface ReviewFinding {
  readonly id: string;
  readonly severity: ReviewFindingSeverity;
  readonly rubric: ReviewRubric;
  readonly summary: string;
  readonly evidence: readonly ReviewEvidence[];
  readonly recommendedChecks: readonly string[];
}

export interface ReviewPacketIssue {
  readonly kind: 'missing-verdict' | 'finding-without-evidence';
  readonly detail: string;
}

export interface ReviewPacket {
  readonly schemaVersion: typeof REVIEW_PACKET_SCHEMA_VERSION;
  readonly verdict: ReviewVerdict;
  readonly sourceRef: string;
  readonly sourceSha256: string;
  readonly sourceChars: number;
  readonly findingCount: number;
  readonly findings: readonly ReviewFinding[];
  readonly issues: readonly ReviewPacketIssue[];
}

export interface ReviewPacketOptions {
  readonly sourceRef: string;
  readonly sourceSha256: string;
}

const BULLET_RE = /^(?:[-*]\s+|\d+[.)]\s+)(.+)$/u;
const VERDICT_RE = /\bVERDICT\s*:\s*(ACCEPTED|NEEDS[\s_-]*FIX|NEEDSFIX)\b/iu;
const FILE_RE =
  /\b((?:[A-Za-z0-9_.@~+-]+\/)*[A-Za-z0-9_.@~+-]+\.(?:cjs|css|go|html|java|js|jsx|json|kt|md|mjs|py|rs|scss|sh|sql|svg|toml|ts|tsx|txt|yaml|yml))(?:[:#L]+([1-9]\d*))?\b/giu;

const cleanLine = (line: string): string => line.trim().replace(/\s+/gu, ' ');

const parseVerdict = (content: string): ReviewVerdict => {
  const match = VERDICT_RE.exec(content);
  const raw = match?.[1]?.toUpperCase().replace(/[\s_-]/gu, '');
  if (raw === 'ACCEPTED') return 'ACCEPTED';
  if (raw === 'NEEDSFIX') return 'NEEDS_FIX';
  return 'UNKNOWN';
};

const severityFrom = (text: string): ReviewFindingSeverity => {
  const lower = text.toLowerCase();
  if (/\b(?:p0|critical|blocker|must fix|data loss|security)\b/u.test(lower)) {
    return 'critical';
  }
  if (/\b(?:p1|major|high|bug|incorrect|broken)\b/u.test(lower)) {
    return 'major';
  }
  if (/\b(?:p2|minor|medium|edge case|coverage|test)\b/u.test(lower)) {
    return 'minor';
  }
  if (/\b(?:p3|nit|low|style|typo)\b/u.test(lower)) {
    return 'nit';
  }
  return 'unknown';
};

const rubricFrom = (text: string): ReviewRubric => {
  const lower = text.toLowerCase();
  if (
    /\b(?:security|secret|credential|injection|permission|trust|trusted|trusts|untrusted)\b/u.test(
      lower,
    )
  ) {
    return 'security';
  }
  if (/\b(?:test|coverage|spec|vitest|assert)\b/u.test(lower)) {
    return 'tests';
  }
  if (/\b(?:bug|correct|incorrect|regression|edge case|logic|wrong|fail)\b/u.test(lower)) {
    return 'correctness';
  }
  if (/\b(?:perf|performance|latency|timeout|memory|quadratic|slow)\b/u.test(lower)) {
    return 'performance';
  }
  if (/\b(?:trace|evidence|provenance|audit|source|line)\b/u.test(lower)) {
    return 'traceability';
  }
  if (/\b(?:integration|cli|wrapper|dispatch|adapter|wire|export)\b/u.test(lower)) {
    return 'integration';
  }
  if (/\b(?:readme|doc|documentation|guide|comment)\b/u.test(lower)) {
    return 'documentation';
  }
  if (/\b(?:policy|approval|gate|contract|invariant)\b/u.test(lower)) {
    return 'policy';
  }
  if (/\b(?:maintain|refactor|duplication|readability|style)\b/u.test(lower)) {
    return 'maintainability';
  }
  return 'other';
};

const parseEvidence = (text: string): readonly ReviewEvidence[] => {
  const seen = new Set<string>();
  const evidence: ReviewEvidence[] = [];
  for (const match of text.matchAll(FILE_RE)) {
    const file = match[1];
    if (file === undefined) continue;
    const lineText = match[2];
    const line =
      lineText === undefined || lineText.length === 0 || !/^\d+$/u.test(lineText)
        ? undefined
        : Number(lineText);
    const key = `${file}:${line ?? ''}`;
    if (seen.has(key)) continue;
    seen.add(key);
    evidence.push(line === undefined ? { file } : { file, line });
  }
  return evidence;
};

const isFindingLine = (line: string): boolean => {
  if (line.length === 0) return false;
  if (/^VERDICT\s*:/iu.test(line)) return false;
  if (BULLET_RE.test(line)) return true;
  if (/\[[Pp][0-3]\]/u.test(line)) return true;
  return parseEvidence(line).length > 0;
};

const findingText = (line: string): string => {
  const bullet = BULLET_RE.exec(line.trim());
  return cleanLine(bullet?.[1] ?? line);
};

const recommendedChecks = (
  rubric: ReviewRubric,
  evidence: readonly ReviewEvidence[],
  summary: string,
): readonly string[] => {
  const checks = new Set<string>();
  const files = evidence.map((item) => item.file);
  if (files.some((file) => /\.(?:ts|tsx|js|jsx|mjs|cjs)$/u.test(file))) {
    checks.add('run npm run check');
  }
  if (files.some((file) => /\.(?:md|mdx)$/u.test(file))) {
    checks.add('run npm run check:docs');
  }
  if (rubric === 'tests' || /\b(?:test|coverage|regression)\b/iu.test(summary)) {
    checks.add('add or update a regression test for this finding');
  }
  if (rubric === 'security' || rubric === 'policy') {
    checks.add('add a policy or trust-boundary assertion before re-review');
  }
  checks.add('re-run independent review on the fixed diff');
  return [...checks];
};

const packetIssues = (
  verdict: ReviewVerdict,
  findings: readonly ReviewFinding[],
): readonly ReviewPacketIssue[] => {
  const issues: ReviewPacketIssue[] = [];
  if (verdict === 'UNKNOWN') {
    issues.push({
      kind: 'missing-verdict',
      detail: 'review output did not contain VERDICT: ACCEPTED or VERDICT: NEEDS FIX',
    });
  }
  findings.forEach((finding) => {
    if (finding.evidence.length === 0) {
      issues.push({
        kind: 'finding-without-evidence',
        detail: `${finding.id} has no file evidence`,
      });
    }
  });
  return issues;
};

export const reviewPacket = (content: string, options: ReviewPacketOptions): ReviewPacket => {
  const verdict = parseVerdict(content);
  const rawLines = content.split(/\r?\n/u).map(cleanLine);
  const findingLines = rawLines
    .filter(isFindingLine)
    .map(findingText)
    .filter((line) => !/^findings?\s*:?$/iu.test(line));
  const findings = findingLines.map((summary, index): ReviewFinding => {
    const evidence = parseEvidence(summary);
    const rubric = rubricFrom(summary);
    return {
      id: `F${String(index + 1)}`,
      severity: severityFrom(summary),
      rubric,
      summary,
      evidence,
      recommendedChecks: recommendedChecks(rubric, evidence, summary),
    };
  });

  return {
    schemaVersion: REVIEW_PACKET_SCHEMA_VERSION,
    verdict,
    sourceRef: options.sourceRef,
    sourceSha256: options.sourceSha256,
    sourceChars: content.length,
    findingCount: findings.length,
    findings,
    issues: packetIssues(verdict, findings),
  };
};

const evidenceText = (evidence: readonly ReviewEvidence[]): string =>
  evidence.length === 0
    ? '(no file evidence)'
    : evidence
        .map((item) => (item.line === undefined ? item.file : `${item.file}:${String(item.line)}`))
        .join(', ');

export const renderReviewPacket = (packet: ReviewPacket): string => {
  const metadata = {
    schemaVersion: packet.schemaVersion,
    verdict: packet.verdict,
    sourceRef: packet.sourceRef,
    sourceSha256: packet.sourceSha256,
    sourceChars: packet.sourceChars,
    findingCount: packet.findingCount,
  };
  const findingLines =
    packet.findings.length === 0
      ? ['- finding: (none)']
      : packet.findings.flatMap((finding) => [
          `- ${finding.id} [${finding.severity}/${finding.rubric}] ${evidenceText(
            finding.evidence,
          )} :: ${finding.summary}`,
          ...finding.recommendedChecks.map((check) => `  - check: ${check}`),
        ]);
  return [
    `[review:packet] verdict=${packet.verdict} findings=${String(packet.findingCount)}`,
    `[review:packet:meta] ${JSON.stringify(metadata)}`,
    '## Findings',
    ...findingLines,
    '## Issues',
    ...(packet.issues.length === 0
      ? ['- issue: (none)']
      : packet.issues.map((issue) => `- issue: ${issue.kind}: ${issue.detail}`)),
    '',
  ].join('\n');
};

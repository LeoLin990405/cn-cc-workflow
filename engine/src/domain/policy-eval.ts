import type { GateResult } from './gate.js';
import type { Policy, PolicyResult, PolicyViolation, Selection } from './policy.js';

/** Banned backend families (the no-Gemini hard rule). */
const isBanned = (name: string): boolean => /gemini|antigravity/iu.test(name);

/** No implementer / reviewer / harness may be a Gemini-family backend. */
export const noGeminiPolicy: Policy = {
  id: 'no-gemini',
  evaluate(selection): readonly PolicyViolation[] {
    const named: ReadonlyArray<readonly [role: string, name: string]> = [
      ...selection.implementers.map((name) => ['implementer', name] as const),
      ...(selection.reviewer !== undefined ? [['reviewer', selection.reviewer] as const] : []),
      ...(selection.harness !== undefined ? [['harness', selection.harness] as const] : []),
    ];
    return named
      .filter(([, name]) => isBanned(name))
      .map(([role, name]) => ({
        policy: 'no-gemini',
        severity: 'fail' as const,
        detail: `${role} "${name}" is a banned Gemini/Antigravity backend (no-Gemini hard rule)`,
      }));
  },
};

/** The reviewer must be independent of the implementers (generation ≠ review). */
export const generationNotReviewPolicy: Policy = {
  id: 'generation-ne-review',
  evaluate(selection): readonly PolicyViolation[] {
    if (selection.reviewer !== undefined && selection.implementers.includes(selection.reviewer)) {
      return [
        {
          policy: 'generation-ne-review',
          severity: 'fail',
          detail: `reviewer "${selection.reviewer}" is also an implementer — generation must be independent of review`,
        },
      ];
    }
    return [];
  },
};

/** A run should have an independent reviewer (warn — degraded, not blocked). */
export const reviewerRequiredPolicy: Policy = {
  id: 'reviewer-required',
  evaluate(selection): readonly PolicyViolation[] {
    if (selection.reviewer === undefined || selection.reviewer.length === 0) {
      return [
        {
          policy: 'reviewer-required',
          severity: 'warn',
          detail: 'no reviewer selected — generation ≠ review needs an independent reviewer',
        },
      ];
    }
    return [];
  },
};

export const DEFAULT_POLICIES: readonly Policy[] = [
  noGeminiPolicy,
  generationNotReviewPolicy,
  reviewerRequiredPolicy,
];

export const evaluatePolicies = (
  policies: readonly Policy[],
  selection: Selection,
): PolicyResult => ({
  violations: policies.flatMap((policy) => policy.evaluate(selection)),
});

/** Project a policy result onto the gate model so it composes with other gates. */
export const policyResultToGate = (result: PolicyResult): GateResult => {
  if (result.violations.length === 0) {
    return { checks: [{ name: 'policies', severity: 'ok', detail: 'all policies passed' }] };
  }
  return {
    checks: result.violations.map((violation) => ({
      name: violation.policy,
      severity: violation.severity,
      detail: violation.detail,
    })),
  };
};

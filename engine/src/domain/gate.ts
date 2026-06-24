/**
 * Deterministic go/no-go gating. A gate yields a list of checks; the run is GO
 * unless any check failed (warnings still GO — bash preflight semantics).
 */
export type GateSeverity = 'ok' | 'warn' | 'fail';

export interface GateCheck {
  readonly name: string;
  readonly severity: GateSeverity;
  readonly detail?: string;
}

export interface GateResult {
  readonly checks: readonly GateCheck[];
}

/** GO iff no check failed. */
export const isGo = (result: GateResult): boolean =>
  !result.checks.some((check) => check.severity === 'fail');

export const failures = (result: GateResult): readonly GateCheck[] =>
  result.checks.filter((check) => check.severity === 'fail');

export const warnings = (result: GateResult): readonly GateCheck[] =>
  result.checks.filter((check) => check.severity === 'warn');

/** Combine several gate results into one (e.g. config gate + policy gate + IO gate). */
export const mergeGates = (...results: readonly GateResult[]): GateResult => ({
  checks: results.flatMap((result) => result.checks),
});

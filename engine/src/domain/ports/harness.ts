import type { Result } from '../result.js';
import type { DispatchError, DispatchRequest, DispatchResult, HealthStatus } from '../dispatch.js';

export type HarnessName = 'ccb' | 'codex' | 'opencode';

/**
 * One job model over a fleet of executors. Adapters wrap the corresponding
 * blocking CLI (`ccb ask` / `codex exec` / `opencode run`); a future remote
 * harness may poll internally and still resolve a single Promise.
 */
export interface Harness {
  readonly name: HarnessName;
  /** Run the prompt on the target agent; resolve with the output or a typed error. */
  dispatch(request: DispatchRequest): Promise<Result<DispatchResult, DispatchError>>;
  /** Whether this harness is ready to accept dispatches (e.g. ccbd mounted). */
  health(): Promise<HealthStatus>;
}

/** Immutable observations for one shutdown, its frozen drafts and its exact service generation. */
export interface ShutdownEvidence {
  readonly editsFrozen: boolean;
  readonly admissionClosed: boolean;
  readonly decisionPersisted: boolean;
  readonly draftsPersisted: boolean;
  readonly outcomesPersisted: boolean;
  readonly workersStopped: boolean;
  readonly serviceStopped: boolean;
}
export interface ShutdownSnapshot {
  readonly shutdownId: string;
  /** Monotonic version of the observed facts, assigned by the trusted supervisor at capture. */
  readonly revision: number;
  readonly observed: ShutdownEvidence | null;
}
const facts = {
  editsFrozen: 'Frozen editor revision',
  admissionClosed: 'Closed task admission',
  decisionPersisted: 'Saved shutdown decision',
  draftsPersisted: 'Saved text and image drafts',
  outcomesPersisted: 'Saved task outcomes',
  workersStopped: 'Stopped owned workers',
  serviceStopped: 'Stopped owned local service',
} satisfies Record<keyof ShutdownEvidence, string>;
const keys = Object.keys(facts) as (keyof ShutdownEvidence)[];
const idPattern =
  /^[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$/;
export type ShutdownState =
  | {readonly phase: 'running'}
  | {readonly phase: 'confirming'; readonly prompt: number}
  | {readonly phase: 'stopping' | 'verified'; readonly id: string}
  | {
      readonly phase: 'unresolved';
      readonly id: string;
      readonly reasons: readonly string[];
    };
type CloseAction =
  | {readonly action: 'ask'; readonly prompt: number}
  | {readonly action: 'recheck'; readonly shutdownId: string}
  | {readonly action: 'hold'}
  | {readonly action: 'allow'};

/** Both native gestures share one decision. The adapter owns async I/O and
 * publishes captured observations. A request or action acknowledgement cannot
 * certify the effects of shutdown. All operations on this object are synchronous. */
export class DesktopShutdown {
  #state: ShutdownState = Object.freeze({phase: 'running'});
  #prompt = 0;
  #revision = -1;
  get state(): ShutdownState {
    return this.#state;
  }

  request(): CloseAction {
    const state = this.#state;
    switch (state.phase) {
      case 'running': {
        const prompt = ++this.#prompt;
        this.#state = Object.freeze({phase: 'confirming', prompt});
        return {action: 'ask', prompt};
      }
      case 'confirming':
        return {action: 'hold'};
      case 'verified':
        return {action: 'allow'};
      default:
        return {action: 'recheck', shutdownId: state.id};
    }
  }

  /** Only the original dialog can initiate work. Cancel, dismissal and an
   * invalid response preserve the running application. */
  answer(
    prompt: number,
    confirmed: boolean,
    shutdownId?: string,
  ):
    | {readonly action: 'start'; readonly shutdownId: string}
    | {readonly action: 'hold'} {
    if (this.#state.phase !== 'confirming' || this.#state.prompt !== prompt)
      return {action: 'hold'};
    if (
      confirmed !== true ||
      typeof shutdownId !== 'string' ||
      !idPattern.test(shutdownId)
    ) {
      this.#state = Object.freeze({phase: 'running'});
      return {action: 'hold'};
    }
    this.#state = Object.freeze({phase: 'stopping', id: shutdownId});
    return {action: 'start', shutdownId};
  }

  /** Ignore out-of-order and unrelated observations. Until the actual native
   * exit, even a complete observation may be superseded by newer evidence. */
  observe(snapshot: ShutdownSnapshot): void {
    const state = this.#state;
    if (
      !('id' in state) ||
      snapshot.shutdownId !== state.id ||
      !Number.isSafeInteger(snapshot.revision) ||
      snapshot.revision <= this.#revision
    )
      return;
    this.#revision = snapshot.revision;
    const missing =
      snapshot.observed === null
        ? [
            ...new Set([
              ...(state.phase === 'unresolved' ? state.reasons : []),
              'Shutdown evidence is unavailable',
            ]),
          ]
        : keys
            .filter((key) => snapshot.observed?.[key] !== true)
            .map((key) => facts[key]);
    this.#state = missing.length
      ? Object.freeze({
          phase: 'unresolved',
          id: state.id,
          reasons: Object.freeze(missing),
        })
      : Object.freeze({phase: 'verified', id: state.id});
  }
}

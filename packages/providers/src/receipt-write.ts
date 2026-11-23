import {addAbortListener} from 'node:events';

/** A missing acknowledgement is uncertain even when the write later succeeds. */
export async function acknowledgedWhileActive(
  signal: AbortSignal,
  write: () => Promise<boolean>,
): Promise<boolean> {
  if (signal.aborted) return false;
  let listener: ReturnType<typeof addAbortListener> | undefined;
  try {
    const saved = await new Promise<boolean>((resolve) => {
      listener = addAbortListener(signal, () => resolve(false));
      write().then(resolve, () => resolve(false));
    });
    return saved && !signal.aborted;
  } catch {
    return false;
  } finally {
    listener?.[Symbol.dispose]();
  }
}

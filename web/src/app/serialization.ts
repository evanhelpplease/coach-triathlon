// Sérialisation JSON qui préserve les Date et les Set (présents dans AppData :
// availability.availableWeekdays/sportDays, injuries[].affectedSports, dates…).
import { emptyAppData, type AppData } from './model';

interface Tagged {
  __t: 'date' | 'set';
  v: unknown;
}

function replacer(this: Record<string, unknown>, key: string, value: unknown): unknown {
  const orig = this[key];
  if (orig instanceof Date) return { __t: 'date', v: orig.toISOString() } satisfies Tagged;
  if (orig instanceof Set) return { __t: 'set', v: [...orig] } satisfies Tagged;
  return value;
}

function reviver(_key: string, value: unknown): unknown {
  if (value && typeof value === 'object' && '__t' in (value as Tagged)) {
    const t = value as Tagged;
    if (t.__t === 'date') return new Date(t.v as string);
    if (t.__t === 'set') return new Set(t.v as unknown[]);
  }
  return value;
}

export function serializeAppData(data: AppData): string {
  return JSON.stringify({ version: 1, data }, replacer);
}

export function deserializeAppData(json: string): AppData {
  const parsed = JSON.parse(json, reviver) as { version?: number; data?: AppData };
  const data = parsed.data ?? (parsed as unknown as AppData);
  // Fusion avec les valeurs par défaut pour tolérer les schémas partiels/anciens.
  const base = emptyAppData();
  return {
    ...base,
    ...data,
    settings: { ...base.settings, ...(data.settings ?? {}) },
  };
}

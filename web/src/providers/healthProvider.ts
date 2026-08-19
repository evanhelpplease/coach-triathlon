// Portage du contrat App/Providers/HealthDataProvider.swift.
// Le `ManualProvider` remplace Garmin/Apple Santé : il renvoie les activités et
// la récupération saisies dans le Journal, et alimente EXACTEMENT le même moteur.
import type { CompletedActivity, DailyReadiness } from '@engine/index';
import { startOfDay } from '@engine/index';

export interface ProviderCapabilities {
  readsActivities: boolean;
  readsReadiness: boolean;
  writesWorkouts: boolean;
}

export interface HealthDataProvider {
  readonly id: string;
  readonly displayName: string;
  readonly capabilities: ProviderCapabilities;
  importActivities(since: Date): Promise<CompletedActivity[]>;
  importReadiness(since: Date): Promise<DailyReadiness[]>;
}

/** Source « saisie manuelle » : lit le journal de l'app. */
export class ManualProvider implements HealthDataProvider {
  readonly id = 'manual';
  readonly displayName = 'Saisie manuelle (Journal)';
  readonly capabilities: ProviderCapabilities = { readsActivities: true, readsReadiness: true, writesWorkouts: false };

  constructor(
    private getActivities: () => CompletedActivity[],
    private getReadiness: () => DailyReadiness[],
  ) {}

  async importActivities(since: Date): Promise<CompletedActivity[]> {
    return this.getActivities().filter((a) => a.start >= since);
  }

  async importReadiness(since: Date): Promise<DailyReadiness[]> {
    return this.getReadiness().filter((r) => r.date >= since);
  }
}

/** Fusionne plusieurs sources : déduplique les activités, agrège la récup par jour. */
export class ProviderCoordinator {
  constructor(private providers: HealthDataProvider[]) {}

  async importActivities(since: Date): Promise<CompletedActivity[]> {
    const all: CompletedActivity[] = [];
    for (const p of this.providers) {
      if (!p.capabilities.readsActivities) continue;
      try {
        all.push(...(await p.importActivities(since)));
      } catch {
        /* source indisponible */
      }
    }
    return this.dedupe(all);
  }

  async importReadiness(since: Date): Promise<DailyReadiness[]> {
    const byDay = new Map<number, DailyReadiness>();
    for (const p of this.providers) {
      if (!p.capabilities.readsReadiness) continue;
      let items: DailyReadiness[];
      try {
        items = await p.importReadiness(since);
      } catch {
        continue;
      }
      for (const r of items) {
        const key = startOfDay(r.date).getTime();
        byDay.set(key, this.mergeReadiness(byDay.get(key), r));
      }
    }
    return [...byDay.values()].sort((a, b) => a.date.getTime() - b.date.getTime());
  }

  private dedupe(activities: CompletedActivity[]): CompletedActivity[] {
    const kept: CompletedActivity[] = [];
    for (const a of [...activities].sort((x, y) => x.start.getTime() - y.start.getTime())) {
      const idx = kept.findIndex((k) => k.sport === a.sport && Math.abs(k.start.getTime() - a.start.getTime()) < 300_000);
      if (idx >= 0) kept[idx] = this.richer(kept[idx], a);
      else kept.push(a);
    }
    return kept;
  }

  private richer(a: CompletedActivity, b: CompletedActivity): CompletedActivity {
    const score = (x: CompletedActivity) =>
      [x.avgPowerW != null, x.avgHr != null, x.avgPaceSecPerKm != null, x.distanceM != null].filter(Boolean).length;
    return score(b) > score(a) ? b : a;
  }

  private mergeReadiness(existing: DailyReadiness | undefined, next: DailyReadiness): DailyReadiness {
    if (!existing) return next;
    return {
      date: existing.date,
      sleepHours: existing.sleepHours ?? next.sleepHours,
      hrRest: existing.hrRest ?? next.hrRest,
      hrvMs: existing.hrvMs ?? next.hrvMs,
      bodyBattery: existing.bodyBattery ?? next.bodyBattery,
      subjective: existing.subjective ?? next.subjective,
    };
  }
}

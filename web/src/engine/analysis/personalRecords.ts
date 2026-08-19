// Portage de Analysis/PersonalRecords.swift.
import type { CompletedActivity } from '../domain/activity';
import type { Sport } from '../domain/types';

export interface PersonalRecord {
  sportKey: string;
  label: string;
  value: string;
  date: Date;
}

function km(m: number): string {
  return `${(m / 1000).toFixed(1)} km`;
}
function durationText(s: number): string {
  const t = Math.round(s);
  const h = Math.trunc(t / 3600);
  const m = Math.trunc((t % 3600) / 60);
  return h > 0 ? `${h} h ${String(m).padStart(2, '0')}` : `${m} min`;
}
function paceText(secPerKm: number): string {
  const s = Math.round(secPerKm);
  return `${Math.trunc(s / 60)}:${String(s % 60).padStart(2, '0')}/km`;
}
function pace100Text(secPer100: number): string {
  const s = Math.round(secPer100);
  return `${Math.trunc(s / 60)}:${String(s % 60).padStart(2, '0')}/100m`;
}

export class PersonalRecords {
  compute(activities: CompletedActivity[]): PersonalRecord[] {
    const records: PersonalRecord[] = [];
    const sports: Sport[] = ['swim', 'bike', 'run'];

    for (const sport of sports) {
      const acts = activities.filter((a) => a.sport === sport);
      if (acts.length === 0) continue;

      const withDist = acts.filter((a) => a.distanceM != null);
      if (withDist.length > 0) {
        const longest = withDist.reduce((best, a) => ((a.distanceM ?? 0) > (best.distanceM ?? 0) ? a : best));
        records.push({ sportKey: sport, label: 'Plus longue distance', value: km(longest.distanceM!), date: longest.start });
      }

      const longestDur = acts.reduce((best, a) => (a.duration > best.duration ? a : best));
      records.push({ sportKey: sport, label: 'Plus longue durée', value: durationText(longestDur.duration), date: longestDur.start });

      if (sport === 'bike') {
        const withPower = acts
          .map((a) => ({ a, p: a.normalizedPowerW ?? a.avgPowerW }))
          .filter((x): x is { a: CompletedActivity; p: number } => x.p != null);
        if (withPower.length > 0) {
          const best = withPower.reduce((b, x) => (x.p > b.p ? x : b));
          records.push({ sportKey: sport, label: 'Meilleure puissance', value: `${best.p} W`, date: best.a.start });
        }
      } else if (sport === 'run') {
        const eligible = acts
          .filter((a) => (a.distanceM ?? 0) >= 3000)
          .map((a) => ({ a, pace: a.avgPaceSecPerKm }))
          .filter((x): x is { a: CompletedActivity; pace: number } => x.pace != null);
        if (eligible.length > 0) {
          const best = eligible.reduce((b, x) => (x.pace < b.pace ? x : b));
          records.push({ sportKey: sport, label: 'Meilleure allure (≥3 km)', value: paceText(best.pace), date: best.a.start });
        }
      } else if (sport === 'swim') {
        const eligible = acts
          .filter((a) => (a.distanceM ?? 0) > 0)
          .map((a) => ({ a, pace: 100.0 / (a.distanceM! / a.duration) }));
        if (eligible.length > 0) {
          const best = eligible.reduce((b, x) => (x.pace < b.pace ? x : b));
          records.push({ sportKey: sport, label: 'Meilleure allure /100 m', value: pace100Text(best.pace), date: best.a.start });
        }
      }
    }
    return records;
  }
}

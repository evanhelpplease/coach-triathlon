// Dérivations analytiques à partir d'AppData : charge (CTL/ATL/TSB/ACWR),
// récupération du jour, plan adapté. Tout repose sur le moteur pur.
import {
  Adapter,
  LoadCalculator,
  LoadSeries,
  ReadinessEvaluator,
  ZoneCalculator,
  addDays,
  startOfDay,
  isSameDay,
  daysBetween,
  type LoadPoint,
  type PlannedSession,
  type DailyReadiness,
  type ReadinessAssessment,
  type CompletedActivity,
  type AthleteProfile,
  type TrainingPlan,
  type AdaptationResult,
} from '@engine/index';
import type { AppData } from './model';

/** Charges quotidiennes contiguës (0 les jours de repos) du plus ancien à aujourd'hui. */
export function dailyLoads(
  activities: CompletedActivity[],
  profile: AthleteProfile,
  today: Date = new Date(),
): Array<{ date: Date; load: number }> {
  if (activities.length === 0) return [];
  const calc = new LoadCalculator();
  const byDay = new Map<number, number>();
  let earliest = startOfDay(today);
  for (const a of activities) {
    const key = startOfDay(a.start).getTime();
    byDay.set(key, (byDay.get(key) ?? 0) + calc.load(a, profile));
    if (a.start < earliest) earliest = startOfDay(a.start);
  }
  const n = daysBetween(earliest, startOfDay(today));
  const out: Array<{ date: Date; load: number }> = [];
  for (let i = 0; i <= n; i++) {
    const day = addDays(earliest, i);
    out.push({ date: day, load: byDay.get(day.getTime()) ?? 0 });
  }
  return out;
}

export function loadSeries(data: AppData, today: Date = new Date()): LoadPoint[] {
  if (!data.profile) return [];
  return new LoadSeries().series(dailyLoads(data.activities, data.profile, today));
}

export function latestLoad(data: AppData, today: Date = new Date()): LoadPoint | null {
  const s = loadSeries(data, today);
  return s.at(-1) ?? null;
}

/**
 * Charge hebdomadaire de départ estimée depuis l'entraînement récent : la CTL
 * (charge chronique moyenne/jour) × 7 ≈ charge hebdo soutenue actuellement.
 * null si l'historique est trop court pour être fiable (< ~10 jours).
 */
export function recentWeeklyLoad(data: AppData, today: Date = new Date()): number | null {
  const series = loadSeries(data, today);
  if (series.length < 10) return null;
  const ctl = series.at(-1)!.ctl;
  if (ctl <= 0) return null;
  return Math.round(Math.max(150, Math.min(900, ctl * 7)));
}

/** Récupération du jour = dernière entrée readiness ≤ aujourd'hui + son évaluation. */
export function todayReadiness(
  data: AppData,
  today: Date = new Date(),
): { readiness: DailyReadiness | null; assessment: ReadinessAssessment | null } {
  const sorted = [...data.readiness].sort((a, b) => a.date.getTime() - b.date.getTime());
  const todays = sorted.filter((r) => r.date <= addDays(startOfDay(today), 1));
  const readiness = todays.at(-1) ?? null;
  if (!readiness) return { readiness: null, assessment: null };
  const history = sorted.filter((r) => r.date < startOfDay(readiness.date));
  return { readiness, assessment: new ReadinessEvaluator().assess(readiness, history) };
}

/** Séances planifiées à venir (>= aujourd'hui). */
export function upcomingSessions(plan: TrainingPlan | null, today: Date = new Date()): PlannedSession[] {
  if (!plan) return [];
  const from = startOfDay(today);
  return plan.sessions.filter((s) => s.date >= from).sort((a, b) => a.date.getTime() - b.date.getTime());
}

export function sessionsOn(plan: TrainingPlan | null, day: Date): PlannedSession[] {
  if (!plan) return [];
  return plan.sessions.filter((s) => isSameDay(s.date, day));
}

/** Applique le moteur d'adaptation au plan à venir, avec le contexte du jour. */
export function adaptedPlan(data: AppData, plan: TrainingPlan | null, today: Date = new Date()): AdaptationResult {
  if (!data.profile || !plan) return { plan: [], events: [] };
  const zones = new ZoneCalculator().zones(data.profile, today);
  const upcoming = upcomingSessions(plan, today);
  const past = plan.sessions.filter((s) => s.date < startOfDay(today));
  const missed = Adapter.detectMissed(past, data.activities);
  const { readiness } = todayReadiness(data, today);
  const history = [...data.readiness].sort((a, b) => a.date.getTime() - b.date.getTime());

  return new Adapter().adapt({
    today: startOfDay(today),
    upcoming,
    missed,
    recentLoad: loadSeries(data, today),
    readinessToday: readiness ?? undefined,
    readinessHistory: history,
    injuries: data.injuries,
    equipment: data.equipment,
    profile: data.profile,
    zones,
  });
}

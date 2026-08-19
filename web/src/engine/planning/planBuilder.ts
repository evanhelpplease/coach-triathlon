// Portage de Planning/PlanBuilder.swift — assemblage complet du plan.
import type { AthleteProfile } from '../domain/profile';
import type { Equipment, Race } from '../domain/equipment';
import { canPractice } from '../domain/equipment';
import { equipmentOn, type TemporaryUnavailability } from '../domain/unavailability';
import { raceGoalGap, type RaceGoalGap } from '../predictions/racePredictor';
import { makeTestSession } from './testSessions';
import type { Discipline, ProgressionLevel, RaceFormat, SessionIntent, Sport, TrainingPhase } from '../domain/types';
import { isTriathlon } from '../domain/types';
import type { PlannedSession } from '../domain/session';
import type { TrainingZones } from '../domain/zones';
import { ZoneCalculator } from '../zones/zoneCalculator';
import { Periodizer, configForProgression, type PlannedWeek } from '../periodization/periodizer';
import { SessionGenerator } from '../sessionGeneration/sessionGenerator';
import { EquipmentSubstitution } from '../adaptation/equipmentSubstitution';
import { addDays, isSameDay, startOfDay, weekday, daysBetween } from '../util/dates';

const WEEKEND_DAYS = new Set([7, 1]); // samedi, dimanche

export interface WeeklyAvailability {
  availableWeekdays: Set<number>; // 1 = dimanche … 7 = samedi
  maxSessionsPerWeek: number;
  sportDays: Partial<Record<Sport, Set<number>>>;
}

export function makeAvailability(p: Partial<WeeklyAvailability> = {}): WeeklyAvailability {
  return {
    availableWeekdays: p.availableWeekdays ?? new Set([2, 3, 4, 5, 6, 7, 1]),
    maxSessionsPerWeek: p.maxSessionsPerWeek ?? 6,
    sportDays: p.sportDays ?? {},
  };
}

function allowedWeekdays(av: WeeklyAvailability, sport: Sport): Set<number> {
  const restricted = av.sportDays[sport];
  if (!restricted || restricted.size === 0) return av.availableWeekdays;
  return new Set([...restricted].filter((d) => av.availableWeekdays.has(d)));
}

export interface TrainingPlan {
  zones: TrainingZones;
  weeks: PlannedWeek[];
  sessions: PlannedSession[];
  rationale: string[];
}

/** Charge totale planifiée d'une semaine (par index). */
export function planWeekLoad(plan: TrainingPlan, index: number): number {
  if (index >= plan.weeks.length) return 0;
  const start = plan.weeks[index].startDate;
  const end = addDays(start, 7);
  return plan.sessions
    .filter((s) => s.date >= start && s.date < end)
    .reduce((sum, s) => sum + s.estimatedLoad, 0);
}

export interface PlanBuilderConfig {
  progression: ProgressionLevel;
  poolMeters: number;
  startingWeeklyLoad: number;
  /** Périodes d'indisponibilité (déplacement, matériel manquant…). */
  unavailabilities: TemporaryUnavailability[];
}

export function defaultPlanConfig(): PlanBuilderConfig {
  return { progression: 'balanced', poolMeters: 25, startingWeeklyLoad: 300, unavailabilities: [] };
}

const PROGRESSION_ORDER: ProgressionLevel[] = ['prudent', 'balanced', 'performance'];

interface Slot {
  sport: Sport;
  intent: SessionIntent;
  isLong: boolean;
}
interface DatedSlot {
  slot: Slot;
  date: Date;
}

export class PlanBuilder {
  private zoneCalc = new ZoneCalculator();
  private periodizer = new Periodizer();
  private substitution = new EquipmentSubstitution();

  /** Plan périodisé vers la dernière course, mini-affûtage avant les intermédiaires. */
  build(
    profile: AthleteProfile,
    equipment: Equipment,
    races: Race[],
    start: Date,
    availability: WeeklyAvailability,
    config: PlanBuilderConfig = defaultPlanConfig(),
  ): TrainingPlan {
    const zones = this.zoneCalc.zones(profile, start);
    const sorted = [...races].sort((a, b) => a.date.getTime() - b.date.getTime());
    const target = sorted.at(-1);
    if (!target) {
      return { zones, weeks: [], sessions: [], rationale: ['Aucune course.'] };
    }
    const gen = new SessionGenerator(config.poolMeters);

    // Ambition : si un objectif de temps est fixé et hors de portée à forme
    // actuelle, on rend la périodisation plus agressive (rampe + intensité).
    let progression = config.progression;
    const gap = target.goalTimeSeconds != null ? raceGoalGap(profile, equipment, target.format, target.goalTimeSeconds) : null;
    if (gap?.verdict === 'behind') {
      progression = PROGRESSION_ORDER[Math.min(2, PROGRESSION_ORDER.indexOf(progression) + 1)];
    }

    const perio = configForProgression(progression, config.startingWeeklyLoad);
    const weeks = this.periodizer.plan(start, target, perio);
    const unavailabilities = config.unavailabilities ?? [];
    // Semaines « spécifiques » (spécifique + affûtage) : cibles orientées objectif.
    const sharpenWeeks = weeks.filter((w) => w.phase === 'specific' || w.phase === 'taper').map((w) => w.index);

    let allSessions: PlannedSession[] = [];
    for (const week of weeks) {
      const weekZones = this.raceZones(week, sharpenWeeks, profile, zones, gap);
      allSessions = allSessions.concat(
        this.buildWeek(week, target.format, profile, equipment, weekZones, availability, progression, gen, unavailabilities),
      );
    }
    // Tests de terrain pour les référentiels manquants (insérés tôt).
    allSessions = this.insertTestSessions(allSessions, profile, equipment, availability, start, config.poolMeters);

    this.applyRaceTapers(allSessions, sorted);

    const rationale = [`Plan périodisé vers « ${target.title} » : ${weeks.length} semaines, pic de forme le jour J.`];
    if (gap) {
      const dm = Math.round(Math.abs(gap.deltaSeconds) / 60);
      if (gap.verdict === 'behind') {
        rationale.push(`Objectif ambitieux (~${dm} min plus rapide que ta forme actuelle) : intensité et rampe renforcées.`);
        rationale.push(`Cibles d'allure/puissance de la phase spécifique orientées vers l'objectif, progressivement (plafonnées pour rester atteignables).`);
      }
      else if (gap.verdict === 'ahead') rationale.push(`Objectif à portée (~${dm} min de marge) : on peut viser plus haut ou sécuriser.`);
      else rationale.push(`Objectif cohérent avec ta forme actuelle : plan calé dessus.`);
    }
    if (unavailabilities.length > 0) rationale.push(`${unavailabilities.length} période(s) d'indisponibilité prise(s) en compte (séances converties).`);
    const missing = this.missingReferentials(profile, equipment);
    if (missing.length > 0) rationale.push(`Référentiels à établir : ${missing.length} test(s) de terrain planifié(s) en début de plan.`);
    if (sorted.length > 1) rationale.push(`${sorted.length} courses programmées : mini-affûtage avant chaque course.`);
    for (const w of weeks.slice(0, 3)) rationale.push(`S${w.index + 1} (${w.phase}) : ${w.rationale}`);

    allSessions.sort((a, b) => a.date.getTime() - b.date.getTime());
    this.assignStableIds(allSessions);
    return { zones, weeks, sessions: allSessions, rationale };
  }

  /**
   * Identifiants déterministes (date+sport+intention+rang du jour) : deux plans
   * identiques produisent les mêmes ids → la synchro agenda reste idempotente
   * même après régénération (pas de doublons d'événements).
   */
  private assignStableIds(sessions: PlannedSession[]): void {
    const p2 = (n: number) => String(n).padStart(2, '0');
    const perSlot = new Map<string, number>();
    for (const s of sessions) {
      const day = `${s.date.getUTCFullYear()}${p2(s.date.getUTCMonth() + 1)}${p2(s.date.getUTCDate())}`;
      const key = `${day}-${s.sport}-${s.intent}`;
      const n = perSlot.get(key) ?? 0;
      perSlot.set(key, n + 1);
      s.id = `ct-${key}-${n}`;
    }
  }

  /** Compatibilité : une seule course cible. */
  buildOne(
    profile: AthleteProfile,
    equipment: Equipment,
    race: Race,
    start: Date,
    availability: WeeklyAvailability,
    config: PlanBuilderConfig = defaultPlanConfig(),
  ): TrainingPlan {
    return this.build(profile, equipment, [race], start, availability, config);
  }

  private applyRaceTapers(sessions: PlannedSession[], races: Race[]): void {
    for (const race of races) {
      const raceDay = startOfDay(race.date);
      for (let i = sessions.length - 1; i >= 0; i--) {
        if (isSameDay(sessions[i].date, raceDay)) sessions.splice(i, 1);
      }
      for (let i = 0; i < sessions.length; i++) {
        const d = daysBetween(startOfDay(sessions[i].date), raceDay);
        if (d === 1 || d === 2) {
          sessions[i].estimatedLoad = Math.round(sessions[i].estimatedLoad * 0.5);
          sessions[i].estimatedDuration *= 0.6;
          if (sessions[i].intent !== 'recovery') sessions[i].intent = 'endurance';
        }
      }
    }
  }

  /** Référentiels manquants dont le sport est praticable → un test chacun. */
  private missingReferentials(profile: AthleteProfile, equipment: Equipment): Sport[] {
    const out: Sport[] = [];
    if (profile.vdot == null && profile.vma == null && canPractice(equipment, 'run')) out.push('run');
    if (profile.ftpWatts == null && canPractice(equipment, 'bike')) out.push('bike');
    if (profile.cssSecPer100m == null && canPractice(equipment, 'swim')) out.push('swim');
    return out;
  }

  /** Place un test de terrain par référentiel manquant, tôt (semaine 0). */
  private insertTestSessions(
    all: PlannedSession[],
    profile: AthleteProfile,
    equipment: Equipment,
    availability: WeeklyAvailability,
    start: Date,
    poolMeters: number,
  ): PlannedSession[] {
    const missing = this.missingReferentials(profile, equipment);
    if (missing.length === 0) return all;

    const week0 = Array.from({ length: 7 }, (_, i) => addDays(start, i)).filter((d) =>
      availability.availableWeekdays.has(weekday(d)),
    );
    if (week0.length === 0) return all;

    const out = [...all];
    missing.forEach((sport, i) => {
      const date = week0[i % week0.length];
      // Retire la séance normale du même sport ce jour-là (le test la remplace).
      for (let j = out.length - 1; j >= 0; j--) {
        if (out[j].sport === sport && isSameDay(out[j].date, date)) out.splice(j, 1);
      }
      out.push(makeTestSession(sport, date, poolMeters));
    });
    return out;
  }

  /**
   * Zones d'une semaine. En phase spécifique/affûtage avec un objectif ambitieux,
   * les référentiels sont poussés vers l'allure objectif — MAIS progressivement
   * (on démarre à mi-chemin) et PLAFONNÉS (+10 % max) pour rester atteignables :
   * viser d'emblée une allure impossible ne fait pas mieux progresser.
   */
  private raceZones(
    week: PlannedWeek,
    sharpenWeeks: number[],
    profile: AthleteProfile,
    baseZones: TrainingZones,
    gap: RaceGoalGap | null,
  ): TrainingZones {
    if (!gap || gap.verdict !== 'behind') return baseZones;
    if (week.phase !== 'specific' && week.phase !== 'taper') return baseZones;

    const factor = Math.min(gap.ratio, 1.1); // +10 % d'amélioration visée au plus
    const idx = sharpenWeeks.indexOf(week.index);
    const pos = sharpenWeeks.length > 1 ? idx / (sharpenWeeks.length - 1) : 1;
    const applied = 1 + (factor - 1) * (0.5 + 0.5 * pos); // mi-chemin → objectif près de la course

    const adjusted: AthleteProfile = {
      ...profile,
      vdot: profile.vdot != null ? profile.vdot * applied : undefined,
      ftpWatts: profile.ftpWatts != null ? Math.round(profile.ftpWatts * applied) : undefined,
      cssSecPer100m: profile.cssSecPer100m != null ? profile.cssSecPer100m / applied : undefined,
    };
    return this.zoneCalc.zones(adjusted, week.startDate);
  }

  private buildWeek(
    week: PlannedWeek,
    format: RaceFormat,
    profile: AthleteProfile,
    equipment: Equipment,
    zones: TrainingZones,
    availability: WeeklyAvailability,
    progression: ProgressionLevel,
    gen: SessionGenerator,
    unavailabilities: TemporaryUnavailability[],
  ): PlannedSession[] {
    const candidateDates = Array.from({ length: 7 }, (_, i) => addDays(week.startDate, i)).filter((d) =>
      availability.availableWeekdays.has(weekday(d)),
    );
    if (candidateDates.length === 0) return [];

    const slots = this.weeklySlots(week.phase, format, profile, progression, week.index);
    const n = Math.min(availability.maxSessionsPerWeek, candidateDates.length);
    if (n <= 0) return [];

    const dated = this.assignDates(slots, candidateDates, availability, n);

    let sessions = dated.map((item) =>
      this.materialize(item.slot.sport, item.slot.intent, week.phase, item.date, zones, profile, equipment, gen, unavailabilities),
    );

    this.scaleToTarget(sessions, week.targetLoad);
    return sessions;
  }

  /**
   * Nombre de séances qualité par semaine. Le socle reste aérobie (polarisation
   * par le VOLUME), mais chaque phase — base comprise — conserve du travail
   * d'intensité pour développer la vitesse en plus de l'endurance.
   */
  private qualityCount(phase: TrainingPhase, prog: ProgressionLevel): number {
    switch (phase) {
      case 'base': return prog === 'prudent' ? 1 : 2; // la base n'est plus un désert de vitesse
      case 'build': return prog === 'prudent' ? 2 : 3;
      case 'specific': return prog === 'prudent' ? 2 : 3;
      case 'taper': return 1;
      case 'recovery': return 0;
    }
  }

  /**
   * Intention d'une séance qualité selon phase, sport et semaine (rotation pour
   * la variété : VMA / seuil / vitesse pure alternent au fil des semaines).
   */
  private qualityIntent(phase: TrainingPhase, sport: Sport, prog: ProgressionLevel, weekIndex: number): SessionIntent {
    const p = weekIndex % 2;
    const t = weekIndex % 3;
    switch (phase) {
      case 'base':
        // Base : on entretient déjà seuil et VMA courte (sans surcharge).
        if (sport === 'run') return p === 0 ? 'threshold' : 'sprint';
        if (sport === 'bike') return p === 0 ? 'tempo' : 'threshold';
        return 'threshold'; // natation au seuil (CSS)
      case 'build':
        // Build : montée en VO2/VMA, seuil consolidé, vitesse pure.
        if (sport === 'run') return t === 0 ? 'vo2' : t === 1 ? 'threshold' : 'sprint';
        if (sport === 'bike') return prog === 'prudent' ? 'threshold' : p === 0 ? 'vo2' : 'threshold';
        return p === 0 ? 'threshold' : 'vo2'; // natation seuil/VO2
      case 'specific':
        // Spécifique : allure/puissance course, avec piqûres de VO2.
        if (sport === 'run') return p === 0 ? 'threshold' : 'vo2';
        return 'threshold';
      case 'taper':
        return 'threshold'; // affûtage : rappels courts au seuil
      case 'recovery':
        return 'endurance';
    }
  }

  private weeklySlots(
    phase: TrainingPhase,
    format: RaceFormat,
    profile: AthleteProfile,
    prog: ProgressionLevel,
    weekIndex: number,
  ): Slot[] {
    const tri = isTriathlon(format);
    let slots: Slot[] = [];

    // Socle aérobie : longues sorties (dominent le volume → polarisation préservée).
    slots.push({ sport: 'run', intent: 'endurance', isLong: true });
    slots.push({ sport: 'bike', intent: 'endurance', isLong: tri });

    // Séances qualité RÉPARTIES sur les disciplines, en rotation d'une semaine à
    // l'autre : la natation et le point faible reçoivent régulièrement de l'intensité.
    const disciplines: Sport[] = tri ? ['run', 'bike', 'swim'] : ['run'];
    const rotated = disciplines.map((_, i) => disciplines[(i + weekIndex) % disciplines.length]);
    const qc = tri ? this.qualityCount(phase, prog) : Math.min(this.qualityCount(phase, prog), 2);
    for (let i = 0; i < qc; i++) {
      const s = rotated[i % rotated.length];
      slots.push({ sport: s, intent: this.qualityIntent(phase, s, prog, weekIndex), isLong: false });
    }

    // Natation aérobie/technique si elle n'a pas déjà eu sa séance qualité cette semaine.
    if (tri && !slots.some((x) => x.sport === 'swim')) {
      slots.push({ sport: 'swim', intent: 'technique', isLong: false });
    }

    // Brick spécifique triathlon en build/spécifique.
    if (tri && (phase === 'build' || phase === 'specific')) {
      slots.push({ sport: 'brick', intent: 'brick', isLong: true });
    }
    // Renforcement (hors affûtage).
    if (phase !== 'taper') slots.push({ sport: 'strength', intent: 'strength', isLong: false });

    // Fillers d'endurance.
    slots = slots.concat(
      tri
        ? [
            { sport: 'bike', intent: 'endurance', isLong: false },
            { sport: 'run', intent: 'endurance', isLong: false },
            { sport: 'swim', intent: 'endurance', isLong: false },
          ]
        : [
            { sport: 'run', intent: 'endurance', isLong: false },
            { sport: 'bike', intent: 'endurance', isLong: false },
          ],
    );

    // Priorise le point faible (volume) juste après le socle des 2 longues.
    const weakest = this.weakestDiscipline(profile);
    if (weakest) {
      const idx = slots.findIndex((s) => (s.sport as string) === (weakest as string) && s.intent === 'endurance');
      if (idx >= 0) {
        const [s] = slots.splice(idx, 1);
        slots.splice(Math.min(2, slots.length), 0, s);
      }
    }
    if (phase === 'recovery') slots = slots.map((s) => ({ sport: s.sport, intent: 'recovery', isLong: false }));
    return slots;
  }

  private weakestDiscipline(profile: AthleteProfile): Discipline | null {
    let weakest: Discipline | null = null;
    let min = Infinity;
    for (const [k, v] of Object.entries(profile.levels)) {
      if (v != null && v < min) {
        min = v;
        weakest = k as Discipline;
      }
    }
    return weakest;
  }

  private assignDates(slots: Slot[], dates: Date[], availability: WeeklyAvailability, maxCount: number): DatedSlot[] {
    const allowed = (slot: Slot): Date[] => {
      const days = allowedWeekdays(availability, slot.sport);
      return dates.filter((d) => days.has(weekday(d)));
    };
    const ordered = slots
      .map((element, offset) => ({ element, offset }))
      .sort((a, b) => {
        const ca = allowed(a.element).length;
        const cb = allowed(b.element).length;
        return ca !== cb ? ca - cb : a.offset - b.offset;
      })
      .map((x) => x.element);

    const used = new Set<number>();
    const result: DatedSlot[] = [];
    for (const slot of ordered) {
      if (result.length >= maxCount) break;
      const options = allowed(slot).filter((d) => !used.has(d.getTime()));
      if (options.length === 0) continue;
      const weekend = options.filter((d) => WEEKEND_DAYS.has(weekday(d)));
      const date = (slot.isLong ? weekend[0] : undefined) ?? options[0];
      used.add(date.getTime());
      result.push({ slot, date });
    }
    return result.sort((a, b) => a.date.getTime() - b.date.getTime());
  }

  private materialize(
    sport: Sport,
    intent: SessionIntent,
    phase: TrainingPhase,
    date: Date,
    zones: TrainingZones,
    profile: AthleteProfile,
    equipment: Equipment,
    gen: SessionGenerator,
    unavailabilities: TemporaryUnavailability[],
  ): PlannedSession {
    // Matériel effectif ce jour-là : une indisponibilité temporaire (déplacement,
    // pas de vélo…) désactive la discipline → la substitution convertit la séance.
    const eq = equipmentOn(equipment, unavailabilities, date);
    const base = gen.generate(sport, intent, phase, date, zones, profile, eq);
    const sub = this.substitution.substitute(base, eq);
    if (!sub.changed) return base;
    const repl = gen.generate(sub.session.sport, intent, phase, date, zones, profile, eq);
    repl.title = sub.session.title;
    repl.notes = sub.explanation;
    return repl;
  }

  private scaleToTarget(sessions: PlannedSession[], target: number): void {
    const sum = sessions.reduce((s, x) => s + x.estimatedLoad, 0);
    if (!(sum > 0) || !(target > 0)) return;
    const factor = Math.min(2.5, Math.max(0.4, target / sum));
    for (const s of sessions) {
      s.estimatedLoad = Math.round(s.estimatedLoad * factor);
      s.estimatedDuration *= factor;
    }
  }
}

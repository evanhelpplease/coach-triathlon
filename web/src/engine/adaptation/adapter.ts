// Portage de Adaptation/Adapter.swift — moteur de règles d'adaptation ordonné.
import type { AthleteProfile } from '../domain/profile';
import type { BodyZone, InjuryRecord } from '../domain/profile';
import type { Equipment } from '../domain/equipment';
import { canPractice } from '../domain/equipment';
import type { CompletedActivity, DailyReadiness } from '../domain/activity';
import type { SessionIntent, Sport } from '../domain/types';
import type { PlannedSession } from '../domain/session';
import type { TrainingZones } from '../domain/zones';
import type { LoadPoint } from '../load/loadModel';
import { SessionGenerator } from '../sessionGeneration/sessionGenerator';
import { EquipmentSubstitution } from './equipmentSubstitution';
import { ReadinessEvaluator } from './readinessEvaluator';
import { isTestSession } from '../planning/testSessions';
import { addDays, isSameDay } from '../util/dates';

export type AdaptationEventKind =
  | 'eased'
  | 'rescheduled'
  | 'deload'
  | 'substituted'
  | 'injuryAdjusted'
  | 'alert'
  | 'recalibrated';

export interface AdaptationEvent {
  id: string;
  kind: AdaptationEventKind;
  date: Date;
  sessionID?: string;
  message: string;
}

let eventCounter = 0;
function makeEvent(kind: AdaptationEventKind, date: Date, message: string, sessionID?: string): AdaptationEvent {
  return { id: `evt-${++eventCounter}`, kind, date, sessionID, message };
}

export interface AdaptationContext {
  today: Date;
  upcoming: PlannedSession[];
  missed?: PlannedSession[];
  recentLoad?: LoadPoint[];
  readinessToday?: DailyReadiness;
  readinessHistory?: DailyReadiness[];
  injuries?: InjuryRecord[];
  equipment: Equipment;
  profile: AthleteProfile;
  zones: TrainingZones;
}

export interface AdaptationResult {
  plan: PlannedSession[];
  events: AdaptationEvent[];
}

export const medicalDisclaimer =
  'Ceci ne remplace pas un avis médical : si la douleur persiste, consulte un professionnel.';

export class Adapter {
  private generator: SessionGenerator;
  private substitution = new EquipmentSubstitution();
  private readiness = new ReadinessEvaluator();

  constructor(generator: SessionGenerator = new SessionGenerator()) {
    this.generator = generator;
  }

  adapt(ctx: AdaptationContext): AdaptationResult {
    // Les séances de TEST sont sanctuarisées : jamais rematérialisées ni allégées
    // (leur protocole doit rester intact pour calibrer les référentiels).
    const tests = ctx.upcoming.filter(isTestSession);
    let plan = ctx.upcoming.filter((s) => !isTestSession(s)).sort((a, b) => a.date.getTime() - b.date.getTime());
    let events: AdaptationEvent[] = [];

    ({ plan, events } = this.applyInjuries(plan, events, ctx));
    ({ plan, events } = this.applyEquipment(plan, events, ctx));
    ({ plan, events } = this.applyReadiness(plan, events, ctx));
    ({ plan, events } = this.applyLoadGuards(plan, events, ctx));
    ({ plan, events } = this.applyReschedule(plan, events, ctx));

    return { plan: [...plan, ...tests].sort((a, b) => a.date.getTime() - b.date.getTime()), events };
  }

  // 1. Blessures
  private injuryPolicy(zone: BodyZone): { forbidden: Set<Sport>; safe: Sport; hint: string } {
    switch (zone) {
      case 'knee': return { forbidden: new Set(['run', 'brick']), safe: 'swim', hint: 'Genou : natation avec pull buoy conservée, vélo allégé, course suspendue.' };
      case 'ankle':
      case 'foot':
      case 'calf': return { forbidden: new Set(['run', 'brick']), safe: 'swim', hint: 'Cheville/pied : impact évité, natation et vélo maintenus.' };
      case 'hamstring': return { forbidden: new Set(['run', 'brick']), safe: 'bike', hint: 'Ischios : pas de vitesse à pied, vélo souple et natation ok.' };
      case 'hip': return { forbidden: new Set(['run', 'brick']), safe: 'swim', hint: 'Hanche : on privilégie natation et vélo doux.' };
      case 'shoulder': return { forbidden: new Set(['swim']), safe: 'bike', hint: 'Épaule : natation suspendue, vélo et course maintenus.' };
      case 'lowerBack': return { forbidden: new Set(['brick']), safe: 'bike', hint: 'Bas du dos : intensité réduite, position vélo surveillée.' };
      case 'other': return { forbidden: new Set([]), safe: 'swim', hint: 'Zone sensible : prudence sur les séances intenses.' };
    }
  }

  private applyInjuries(plan: PlannedSession[], events: AdaptationEvent[], ctx: AdaptationContext): AdaptationResult {
    const out = [...plan];
    const ev = [...events];
    const active = (ctx.injuries ?? []).filter((i) => i.intensity >= 3);
    if (active.length === 0) return { plan: out, events: ev };

    for (const injury of active) {
      const policy = this.injuryPolicy(injury.zone);
      for (let i = 0; i < out.length; i++) {
        if (!policy.forbidden.has(out[i].sport)) continue;
        const safe = canPractice(ctx.equipment, policy.safe) ? policy.safe : 'strength';
        const repl = this.rematerialize(out[i], safe, 'recovery', ctx);
        repl.notes = `${policy.hint} ${medicalDisclaimer}`;
        ev.push(makeEvent('injuryAdjusted', out[i].date, `${policy.hint} ${medicalDisclaimer}`, out[i].id));
        out[i] = repl;
      }
    }
    return { plan: out, events: ev };
  }

  // 2. Matériel
  private applyEquipment(plan: PlannedSession[], events: AdaptationEvent[], ctx: AdaptationContext): AdaptationResult {
    const out = [...plan];
    const ev = [...events];
    for (let i = 0; i < out.length; i++) {
      const r = this.substitution.substitute(out[i], ctx.equipment);
      if (!r.changed) continue;
      const repl = this.rematerialize(out[i], r.session.sport, out[i].intent, ctx);
      repl.title = r.session.title;
      repl.notes = r.explanation;
      repl.estimatedLoad = r.session.estimatedLoad;
      out[i] = repl;
      ev.push(makeEvent('substituted', out[i].date, r.explanation, out[i].id));
    }
    return { plan: out, events: ev };
  }

  // 3. Récupération du jour
  private applyReadiness(plan: PlannedSession[], events: AdaptationEvent[], ctx: AdaptationContext): AdaptationResult {
    if (!ctx.readinessToday) return { plan, events };
    const a = this.readiness.assess(ctx.readinessToday, ctx.readinessHistory ?? []);
    if (a.level === 'good') return { plan, events };

    const out = [...plan];
    const ev = [...events];
    const todays = out.map((_, i) => i).filter((i) => isSameDay(out[i].date, ctx.today));
    if (todays.length === 0) return { plan: out, events: ev };
    const hardest = todays.reduce((best, i) => (out[i].estimatedLoad > out[best].estimatedLoad ? i : best), todays[0]);

    if (a.level === 'low') {
      out[hardest] = this.rematerialize(out[hardest], out[hardest].sport, 'recovery', ctx);
      ev.push(makeEvent('eased', out[hardest].date, `Récupération basse — on allège aujourd'hui pour mieux progresser demain. (${a.reasons[0] ?? ''})`, out[hardest].id));
    } else {
      const softer = this.downshift(out[hardest].intent);
      if (softer !== out[hardest].intent) {
        out[hardest] = this.rematerialize(out[hardest], out[hardest].sport, softer, ctx);
        ev.push(makeEvent('eased', out[hardest].date, "Forme moyenne : intensité réduite d'un cran aujourd'hui.", out[hardest].id));
      }
    }
    return { plan: out, events: ev };
  }

  private downshift(intent: SessionIntent): SessionIntent {
    switch (intent) {
      case 'vo2':
      case 'sprint': return 'threshold';
      case 'threshold': return 'tempo';
      case 'tempo': return 'endurance';
      default: return intent;
    }
  }

  // 4. Garde-fous de charge
  private applyLoadGuards(plan: PlannedSession[], events: AdaptationEvent[], ctx: AdaptationContext): AdaptationResult {
    const last = (ctx.recentLoad ?? []).at(-1);
    if (!last) return { plan, events };
    const out = [...plan];
    const ev = [...events];

    if (last.acwr > 1.5) {
      const horizon = addDays(ctx.today, 7);
      for (let i = 0; i < out.length; i++) {
        if (out[i].date <= horizon) {
          out[i] = { ...out[i], estimatedLoad: Math.round(out[i].estimatedLoad * 0.7), estimatedDuration: out[i].estimatedDuration * 0.8 };
        }
      }
      ev.push(makeEvent('deload', ctx.today, `Charge aiguë élevée (ACWR ${last.acwr.toFixed(2)}) : semaine allégée de 30 % pour prévenir la blessure.`));
    }

    if (last.tsb < -25) {
      ev.push(makeEvent('alert', ctx.today, `Fraîcheur très basse (TSB ${Math.trunc(last.tsb)}) : priorité au sommeil, on lève le pied 48 h.`));
    }
    return { plan: out, events: ev };
  }

  // 5. Rattrapage des séances manquées
  private applyReschedule(plan: PlannedSession[], events: AdaptationEvent[], ctx: AdaptationContext): AdaptationResult {
    const missed = ctx.missed ?? [];
    if (missed.length === 0) return { plan, events };
    const out = [...plan];
    const ev = [...events];
    const acwr = (ctx.recentLoad ?? []).at(-1)?.acwr ?? 0;

    for (const m of missed) {
      if (acwr > 1.2) {
        ev.push(makeEvent('alert', ctx.today, `Séance « ${m.title} » non rattrapée volontairement : on ne surcharge pas une semaine déjà lourde.`, m.id));
        continue;
      }
      let placed = false;
      for (let offset = 1; offset <= 7; offset++) {
        const day = addDays(ctx.today, offset);
        const occupied = out.some((s) => isSameDay(s.date, day));
        if (!occupied) {
          const moved = { ...m, date: day, estimatedLoad: Math.round(m.estimatedLoad * 0.9) };
          out.push(moved);
          ev.push(makeEvent('rescheduled', day, `Séance « ${m.title} » replacée sans surcharger la semaine.`, m.id));
          placed = true;
          break;
        }
      }
      if (!placed) {
        ev.push(makeEvent('alert', ctx.today, `Pas de créneau libre pour « ${m.title} » : on la laisse filer plutôt que d'entasser.`, m.id));
      }
    }
    return { plan: out, events: ev };
  }

  private rematerialize(s: PlannedSession, sport: Sport, intent: SessionIntent, ctx: AdaptationContext): PlannedSession {
    const nw = this.generator.generate(sport, intent, s.phase ?? 'base', s.date, ctx.zones, ctx.profile, ctx.equipment);
    nw.id = s.id;
    return nw;
  }

  /** Détecte les séances passées non réalisées (même jour + même sport). */
  static detectMissed(pastPlanned: PlannedSession[], completed: CompletedActivity[]): PlannedSession[] {
    return pastPlanned.filter(
      (planned) => !completed.some((act) => act.sport === planned.sport && isSameDay(act.start, planned.date)),
    );
  }
}

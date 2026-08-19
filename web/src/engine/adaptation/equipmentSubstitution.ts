// Portage de Adaptation/EquipmentSubstitution.swift.
import { canPractice, type Equipment } from '../domain/equipment';
import type { Sport } from '../domain/types';
import type { PlannedSession } from '../domain/session';

export interface SubstitutionResult {
  session: PlannedSession;
  changed: boolean;
  explanation: string;
}

function sportLabel(s: Sport): string {
  switch (s) {
    case 'swim': return 'Natation';
    case 'bike': return 'Vélo';
    case 'run': return 'Course';
    case 'strength': return 'Renforcement';
    case 'brick': return 'Brick';
  }
}

/** Facteur de conversion de charge d'un sport source vers un sport cible. */
function loadKept(from: Sport, to: Sport): number {
  if (from === 'bike' && to === 'run') return 0.85;
  if (from === 'swim' && to === 'strength') return 0.6;
  if (from === 'run' && to === 'bike') return 1.0;
  return 0.8;
}

export class EquipmentSubstitution {
  substitute(session: PlannedSession, equipment: Equipment): SubstitutionResult {
    if (canPractice(equipment, session.sport)) {
      return { session, changed: false, explanation: '' };
    }

    switch (session.sport) {
      case 'bike':
        if (canPractice(equipment, 'run')) {
          return this.convert(session, 'run', 'Pas de vélo : converti en course d\'intensité équivalente. On rebascule dès que le vélo revient.');
        }
        return this.convert(session, 'strength', 'Pas de vélo ni de course : maintien via PPG spécifique vélo (gainage, chaîne postérieure).');

      case 'swim': {
        const why = equipment.hasDrylandCords
          ? "Pas d'accès à l'eau : traction élastique à sec + mobilité épaules, technique conservée."
          : "Pas d'accès à l'eau : renforcement spécifique nage + mobilité épaules à la place.";
        return this.convert(session, 'strength', why);
      }

      case 'run':
        if (equipment.hasTreadmill) {
          const s = { ...session, notes: `Sur tapis : ${session.notes}` };
          return { session: s, changed: true, explanation: 'Course déplacée sur tapis.' };
        }
        if (canPractice(equipment, 'bike')) {
          return this.convert(session, 'bike', 'Course indisponible : converti en vélo d\'intensité équivalente (préserve les articulations).');
        }
        return this.convert(session, 'strength', 'Ni course ni vélo : renforcement + mobilité.');

      case 'brick':
        if (canPractice(equipment, 'run')) {
          return this.convert(session, 'run', "Brick impossible sans vélo : séance course seule d'intensité proche.");
        }
        return this.convert(session, 'strength', 'Brick impossible : renforcement de substitution.');

      case 'strength':
        return { session, changed: false, explanation: '' };
    }
  }

  private convert(session: PlannedSession, target: Sport, explanation: string): SubstitutionResult {
    const kept = loadKept(session.sport, target);
    const s: PlannedSession = {
      ...session,
      sport: target,
      estimatedLoad: Math.round(session.estimatedLoad * kept),
      estimatedDuration: session.estimatedDuration * kept,
      title: `${sportLabel(target)} · remplace ${sportLabel(session.sport).toLowerCase()}`,
      notes: explanation,
      steps: [],
    };
    return { session: s, changed: true, explanation };
  }
}

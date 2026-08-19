// Portage de SessionGeneration/SessionGenerator.swift.
import type { AthleteProfile } from '../domain/profile';
import type { Equipment } from '../domain/equipment';
import type { SessionIntent, Sport, TrainingPhase } from '../domain/types';
import { makePlannedSession, Target, type PlannedSession, type StepTarget } from '../domain/session';
import type { TrainingZones } from '../domain/zones';
import { PlannedLoad, SessionBuilder } from './plannedLoad';

export class SessionGenerator {
  poolMeters: number;

  constructor(poolMeters = 25) {
    this.poolMeters = poolMeters;
  }

  generate(
    sport: Sport,
    intent: SessionIntent,
    phase: TrainingPhase,
    date: Date,
    zones: TrainingZones,
    profile: AthleteProfile,
    equipment: Equipment,
  ): PlannedSession {
    const b = new SessionBuilder();
    let title: string;

    switch (sport) {
      case 'run': title = this.buildRun(b, intent, phase, zones); break;
      case 'bike': title = this.buildBike(b, intent, phase, zones, equipment); break;
      case 'swim': title = this.buildSwim(b, intent, phase, zones, profile); break;
      case 'strength': title = this.buildStrength(b, phase, equipment); break;
      case 'brick': title = this.buildBrick(b, phase, zones, equipment); break;
    }

    return makePlannedSession({
      date,
      sport,
      intent,
      title,
      steps: b.steps,
      estimatedLoad: Math.round(b.load),
      estimatedDuration: b.seconds,
      notes: this.notes(sport, equipment),
      phase,
    });
  }

  private phaseVolume(phase: TrainingPhase): number {
    switch (phase) {
      case 'base': return 0.9;
      case 'build': return 1.1;
      case 'specific': return 1.2;
      case 'taper': return 0.6;
      case 'recovery': return 0.5;
    }
  }

  private runTarget(zone: number, zones: TrainingZones): StepTarget {
    const z = zones.runPace.find((x) => x.zone === zone);
    if (z) return Target.paceRange(z.lower, z.upper);
    const hrZone = [2, 2, 4, 5, 5][Math.min(Math.max(zone, 1), 5) - 1];
    return Target.hrZone(hrZone);
  }

  private powerTarget(zone: number, zones: TrainingZones): StepTarget {
    const z = zones.power.find((x) => x.zone === zone);
    if (z) {
      const hi = Number.isFinite(z.upper) ? z.upper : z.lower * 1.2;
      return Target.powerRange(z.lower, hi);
    }
    const hrZone = [1, 2, 3, 4, 5, 5, 5][Math.min(Math.max(zone, 1), 7) - 1];
    return Target.hrZone(hrZone);
  }

  private swimTarget(zone: number, zones: TrainingZones): StepTarget {
    const z = zones.swimPace.find((x) => x.zone === zone);
    if (z) return Target.swimPaceRange(z.lower, z.upper);
    return Target.rpe([3, 5, 7, 8, 9][Math.min(Math.max(zone, 1), 5) - 1]);
  }

  private buildRun(b: SessionBuilder, intent: SessionIntent, phase: TrainingPhase, zones: TrainingZones): string {
    const vol = this.phaseVolume(phase);
    b.addTimed('warmup', 600, PlannedLoad.warmupIF, this.runTarget(1, zones), "Montée progressive, gammes en fin d'échauffement");
    switch (intent) {
      case 'endurance': {
        const main = 2400.0 * vol;
        b.addTimed('work', main, PlannedLoad.workIF('endurance'), this.runTarget(1, zones), 'Allure conversationnelle, cadence 175–180');
        // Lignes droites (strides) : entretien de la vitesse et de la foulée, sans charge notable.
        if (phase === 'base' || phase === 'build' || phase === 'specific') {
          b.addRepeat(
            4,
            { kind: 'work', sec: 20, ifV: PlannedLoad.workIF('sprint'), target: this.runTarget(5, zones), cue: 'Lignes droites : 4×20″ accélérations souples et relâchées' },
            { sec: 40, target: this.runTarget(1, zones) },
          );
        }
        break;
      }
      case 'tempo':
        b.addTimed('work', 1500 * vol, PlannedLoad.workIF('tempo'), this.runTarget(2, zones), 'Tempo soutenu mais contrôlé');
        break;
      case 'threshold': {
        const reps = Math.round(4 * vol);
        b.addRepeat(reps, { kind: 'work', sec: 360, ifV: PlannedLoad.workIF('threshold'), target: this.runTarget(3, zones), cue: 'Au seuil, relâché' }, { sec: 120, target: this.runTarget(1, zones) });
        break;
      }
      case 'vo2': {
        const reps = Math.round(6 * vol);
        b.addRepeat(reps, { kind: 'work', sec: 180, ifV: PlannedLoad.workIF('vo2'), target: this.runTarget(4, zones), cue: 'Dur mais régulier' }, { sec: 180, target: this.runTarget(1, zones) });
        break;
      }
      case 'sprint': {
        const reps = Math.round(8 * vol);
        b.addRepeat(reps, { kind: 'work', sec: 20, ifV: PlannedLoad.workIF('sprint'), target: this.runTarget(5, zones), cue: 'Foulée ample, explosif' }, { sec: 100, target: this.runTarget(1, zones) });
        break;
      }
      default:
        b.addTimed('work', 1800 * vol, PlannedLoad.workIF('recovery'), this.runTarget(1, zones), 'Footing très souple');
    }
    b.addTimed('cooldown', 300, PlannedLoad.recoveryIF, this.runTarget(1, zones), 'Retour au calme');
    return `Course — ${this.label(intent)}`;
  }

  private buildBike(b: SessionBuilder, intent: SessionIntent, phase: TrainingPhase, zones: TrainingZones, equipment: Equipment): string {
    const vol = this.phaseVolume(phase);
    const aeroCue = equipment.hasAeroBars ? 'Tenir la position aéro sur les efforts' : undefined;
    b.addTimed('warmup', 600, PlannedLoad.warmupIF, this.powerTarget(2, zones), 'Montées de cadence 3×30"');
    switch (intent) {
      case 'endurance':
        b.addTimed('work', 3000 * vol, PlannedLoad.workIF('endurance'), this.powerTarget(2, zones), aeroCue ?? 'Cadence 85–95');
        break;
      case 'tempo':
        b.addTimed('work', 1800 * vol, PlannedLoad.workIF('tempo'), this.powerTarget(3, zones), aeroCue);
        break;
      case 'threshold': {
        const reps = Math.round(3 * vol);
        b.addRepeat(reps, { kind: 'work', sec: 600, ifV: PlannedLoad.workIF('threshold'), target: this.powerTarget(4, zones), cue: aeroCue ?? 'Puissance régulière au seuil' }, { sec: 300, target: this.powerTarget(1, zones) });
        break;
      }
      case 'vo2': {
        const reps = Math.round(5 * vol);
        b.addRepeat(reps, { kind: 'work', sec: 240, ifV: PlannedLoad.workIF('vo2'), target: this.powerTarget(5, zones), cue: 'Effort maximal soutenable 4 min' }, { sec: 240, target: this.powerTarget(1, zones) });
        break;
      }
      case 'sprint': {
        const reps = Math.round(6 * vol);
        b.addRepeat(reps, { kind: 'work', sec: 15, ifV: PlannedLoad.workIF('sprint'), target: this.powerTarget(6, zones), cue: 'Sprint départ arrêté' }, { sec: 225, target: this.powerTarget(1, zones) });
        break;
      }
      default:
        b.addTimed('work', 2400 * vol, PlannedLoad.workIF('recovery'), this.powerTarget(1, zones), 'Récup active, jambes légères');
    }
    b.addTimed('cooldown', 300, PlannedLoad.recoveryIF, this.powerTarget(1, zones), 'Retour au calme');
    return `Vélo — ${this.label(intent)}`;
  }

  private buildSwim(b: SessionBuilder, intent: SessionIntent, phase: TrainingPhase, zones: TrainingZones, profile: AthleteProfile): string {
    const css = profile.cssSecPer100m ?? 120;
    const lengthsPer100 = Math.round(100.0 / this.poolMeters);
    b.addLengths('warmup', lengthsPer100 * 3, this.poolMeters, css, PlannedLoad.warmupIF, this.swimTarget(1, zones), 'Souple, respiration bilatérale');
    // Éducatifs systématiques.
    b.addLengths('work', lengthsPer100 * 2, this.poolMeters, css, PlannedLoad.workIF('technique'), Target.rpe(4), 'Éducatifs : rattrapé, poings fermés');
    const vol = this.phaseVolume(phase);
    switch (intent) {
      case 'technique':
        b.addLengths('work', lengthsPer100 * 6, this.poolMeters, css, PlannedLoad.workIF('technique'), Target.rpe(5), 'Focus technique, tempo maîtrisé');
        break;
      case 'endurance':
        b.addLengths('work', Math.trunc(lengthsPer100 * 12 * vol), this.poolMeters, css, PlannedLoad.workIF('endurance'), this.swimTarget(2, zones), 'Continu régulier');
        break;
      case 'threshold': {
        const reps = Math.round(8 * vol);
        for (let i = 0; i < reps; i++) {
          b.addLengths('work', lengthsPer100, this.poolMeters, css, PlannedLoad.workIF('threshold'), this.swimTarget(3, zones), '100 au seuil (CSS)');
        }
        break;
      }
      case 'vo2': {
        const reps = Math.round(10 * vol);
        for (let i = 0; i < reps; i++) {
          b.addLengths('work', Math.max(1, Math.trunc(lengthsPer100 / 2)), this.poolMeters, css, PlannedLoad.workIF('vo2'), this.swimTarget(4, zones), '50 rapide');
        }
        break;
      }
      default:
        b.addLengths('work', lengthsPer100 * 8, this.poolMeters, css, PlannedLoad.workIF('endurance'), this.swimTarget(2, zones), 'Aérobie');
    }
    b.addLengths('cooldown', lengthsPer100 * 2, this.poolMeters, css, PlannedLoad.recoveryIF, this.swimTarget(1, zones), 'Décrassage');
    return `Natation — ${this.label(intent)}`;
  }

  private buildStrength(b: SessionBuilder, phase: TrainingPhase, equipment: Equipment): string {
    b.addTimed('warmup', 300, PlannedLoad.warmupIF, Target.rpe(3), 'Mobilité hanches/épaules, activation');
    const rounds = phase === 'base' ? 4 : 3;
    b.addRepeat(
      rounds,
      {
        kind: 'work',
        sec: 480,
        ifV: PlannedLoad.workIF('strength'),
        target: Target.rpe(equipment.strengthAccess === 'gym' ? 8 : 7),
        cue: equipment.strengthAccess === 'bodyweightOnly' ? 'Gainage, fentes, pont fessier, pompes' : 'Squat, soulevé de terre, gainage',
      },
      { sec: 120, target: Target.rpe(2) },
    );
    b.addTimed('cooldown', 300, PlannedLoad.recoveryIF, Target.rpe(2), 'Étirements doux');
    return 'Renforcement — préventif';
  }

  private buildBrick(b: SessionBuilder, phase: TrainingPhase, zones: TrainingZones, equipment: Equipment): string {
    const vol = this.phaseVolume(phase);
    b.addTimed('warmup', 600, PlannedLoad.warmupIF, this.powerTarget(2, zones));
    b.addTimed('work', 2400 * vol, PlannedLoad.workIF('brick'), this.powerTarget(3, zones), equipment.hasAeroBars ? 'Vélo en position aéro, allure course cible' : 'Vélo allure course cible');
    b.addTimed('work', 1200 * vol, PlannedLoad.workIF('brick'), this.runTarget(2, zones), 'Transition rapide, jambes lourdes normal, monter en allure progressivement');
    b.addTimed('cooldown', 300, PlannedLoad.recoveryIF, this.runTarget(1, zones));
    return 'Brick — enchaînement vélo/course';
  }

  private label(intent: SessionIntent): string {
    switch (intent) {
      case 'recovery': return 'récupération';
      case 'endurance': return 'endurance';
      case 'tempo': return 'tempo';
      case 'threshold': return 'seuil';
      case 'vo2': return 'VO2max';
      case 'sprint': return 'sprint';
      case 'technique': return 'technique';
      case 'brick': return 'brick';
      case 'strength': return 'force';
    }
  }

  private notes(sport: Sport, equipment: Equipment): string {
    if (sport === 'swim' && !equipment.poolAccess && !equipment.openWaterAccess) {
      return "Pas d'accès à l'eau : à convertir en travail à sec (voir adaptation matériel).";
    }
    if (sport === 'bike' && equipment.hasSmartTrainer) {
      return 'Home trainer connecté : séance exécutable en ERG.';
    }
    return '';
  }
}

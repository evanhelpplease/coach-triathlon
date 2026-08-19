// Portage de SessionGeneration/PlannedLoad.swift.
import type { SessionIntent } from '../domain/types';
import { Duration, type StepKind, type StepTarget, type WorkoutStep } from '../domain/session';

/** charge = Σ durée_h · IF² · 100 (1 h à IF 1.0 = 100). */
export const PlannedLoad = {
  workIF(intent: SessionIntent): number {
    switch (intent) {
      case 'recovery': return 0.55;
      case 'endurance': return 0.68;
      case 'tempo': return 0.85;
      case 'threshold': return 0.95;
      case 'vo2': return 1.08;
      case 'sprint': return 1.2;
      case 'technique': return 0.62;
      case 'brick': return 0.82;
      case 'strength': return 0.75;
    }
  },
  warmupIF: 0.6,
  recoveryIF: 0.5,
};

export interface RepeatWork {
  kind: StepKind;
  sec: number;
  ifV: number;
  target: StepTarget;
  cue?: string;
}
export interface RepeatRecovery {
  sec: number;
  target: StepTarget;
}

/** Accumule les pas d'une séance, sa charge estimée et sa durée. */
export class SessionBuilder {
  steps: WorkoutStep[] = [];
  load = 0;
  seconds = 0;

  addTimed(kind: StepKind, s: number, ifValue: number, target: StepTarget, cue?: string): void {
    this.steps.push({ kind, duration: Duration.time(s), target, cue });
    this.load += (s / 3600.0) * ifValue * ifValue * 100.0;
    this.seconds += s;
  }

  addRepeat(times: number, work: RepeatWork, recovery: RepeatRecovery | null): void {
    const children: WorkoutStep[] = [
      { kind: work.kind, duration: Duration.time(work.sec), target: work.target, cue: work.cue },
    ];
    if (recovery) {
      children.push({ kind: 'recovery', duration: Duration.time(recovery.sec), target: recovery.target });
    }
    this.steps.push({ kind: 'repeatBlock', duration: Duration.time(0), target: { kind: 'free' }, repeats: times, children });
    this.load += times * (work.sec / 3600.0) * work.ifV * work.ifV * 100.0;
    this.seconds += times * work.sec;
    if (recovery) {
      this.load += times * (recovery.sec / 3600.0) * PlannedLoad.recoveryIF * PlannedLoad.recoveryIF * 100.0;
      this.seconds += times * recovery.sec;
    }
  }

  addLengths(
    kind: StepKind,
    count: number,
    poolMeters: number,
    cssSecPer100m: number,
    ifValue: number,
    target: StepTarget,
    cue?: string,
  ): void {
    this.steps.push({ kind, duration: Duration.lengths(count, poolMeters), target, cue });
    const meters = count * poolMeters;
    const s = (meters / 100.0) * cssSecPer100m;
    this.load += (s / 3600.0) * ifValue * ifValue * 100.0;
    this.seconds += s;
  }
}

// Modèle de données applicatif persisté (profil, matériel, journal, réglages…).
import {
  makeEquipment,
  makeAvailability,
  makeProfile,
  makeRace,
  makeActivity,
  addDays,
  type AthleteProfile,
  type Equipment,
  type Race,
  type WeeklyAvailability,
  type InjuryRecord,
  type CompletedActivity,
  type DailyReadiness,
  type ProgressionLevel,
  type Sport,
  type TemporaryUnavailability,
  SkillLevel,
} from '@engine/index';

export interface AppSettings {
  poolMeters: number;
  startingWeeklyLoad: number;
  city?: string;
  /** Client ID OAuth Google (Calendar). Vide = synchro agenda désactivée. */
  googleClientId?: string;
  /** ID du calendrier dédié « Coach Triathlon IA » créé par l'app. */
  googleCalendarId?: string;
  /** Synchro agenda auto à chaque changement de plan. */
  calendarAutoSync: boolean;
}

export interface AppData {
  profile: AthleteProfile | null;
  equipment: Equipment;
  races: Race[];
  availability: WeeklyAvailability;
  injuries: InjuryRecord[];
  unavailabilities: TemporaryUnavailability[]; // indisponibilités temporaires
  activities: CompletedActivity[]; // journal — entraînements réalisés
  readiness: DailyReadiness[]; // journal — sommeil / récup / check-in
  progression: ProgressionLevel;
  settings: AppSettings;
  onboardingComplete: boolean;
  /** Mois-jour du dernier plan généré (pour éviter les régénérations inutiles). */
  planGeneratedAt: string | null;
  /** Checklist matériel cochée par course (raceId → clés d'items). */
  raceChecklists: Record<string, string[]>;
}

export function defaultSettings(): AppSettings {
  return { poolMeters: 25, startingWeeklyLoad: 300, calendarAutoSync: true };
}

export function emptyAppData(): AppData {
  return {
    profile: null,
    equipment: makeEquipment(),
    races: [],
    availability: makeAvailability(),
    injuries: [],
    unavailabilities: [],
    activities: [],
    readiness: [],
    progression: 'balanced',
    settings: defaultSettings(),
    onboardingComplete: false,
    planGeneratedAt: null,
    raceChecklists: {},
  };
}

// MARK: - Athlète démo (données simulées cohérentes)

export function demoAppData(today: Date = new Date()): AppData {
  const profile = makeProfile({
    birthDate: new Date(Date.UTC(1995, 4, 12)),
    sex: 'male',
    heightCm: 179,
    weightKg: 71,
    hrMax: 191,
    hrRest: 47,
    ftpWatts: 255,
    cssSecPer100m: 96,
    vdot: 51,
    vma: 16.5,
    levels: { swim: SkillLevel.novice, bike: SkillLevel.advanced, run: SkillLevel.intermediate },
  });

  const equipment = makeEquipment({
    hasBike: true,
    bikeType: 'road',
    bikeWeightKg: 8.2,
    hasAeroBars: true,
    hasPowerMeter: true,
    hasSmartTrainer: true,
    poolAccess: true,
    openWaterAccess: true,
    hasWetsuit: true,
    runOutdoor: true,
    hasTreadmill: false,
    strengthAccess: 'homeWeights',
  });

  const race = makeRace({
    date: addDays(today, 11 * 7 + 3),
    format: 'olympic',
    priority: 'a',
    title: 'Triathlon M — Lac de Vouglans',
    goalTimeSeconds: 2 * 3600 + 5 * 60, // objectif 2 h 05
  });

  const availability = makeAvailability({ maxSessionsPerWeek: 6 });

  // Historique d'activités réalisées sur ~28 jours.
  const activities: CompletedActivity[] = [];
  const sportsCycle: Sport[] = ['run', 'bike', 'swim', 'run', 'bike', 'strength', 'run'];
  for (let d = 28; d >= 1; d--) {
    const day = addDays(today, -d);
    const sport = sportsCycle[d % sportsCycle.length];
    if (d % 7 === 0) continue; // jour de repos hebdo
    switch (sport) {
      case 'run':
        activities.push(makeActivity({ sport: 'run', start: day, duration: 2700 + (d % 3) * 600, distanceM: 8000 + (d % 4) * 1500, avgHr: 148 + (d % 5), avgPaceSecPerKm: 322 - (28 - d) * 1.2, hrDriftPct: 3 + (d % 4), source: 'manual' }));
        break;
      case 'bike':
        activities.push(makeActivity({ sport: 'bike', start: day, duration: 3600 + (d % 3) * 900, distanceM: 30000, avgPowerW: 190 + (d % 6), normalizedPowerW: 205 + (d % 6), avgHr: 142, source: 'manual' }));
        break;
      case 'swim':
        activities.push(makeActivity({ sport: 'swim', start: day, duration: 2400, distanceM: 2200, poolLengths: 88, avgHr: 138, source: 'manual' }));
        break;
      case 'strength':
        activities.push(makeActivity({ sport: 'strength', start: day, duration: 2400, rpe: 6, source: 'manual' }));
        break;
    }
  }

  // Récupération / sommeil sur ~14 jours.
  const readiness: DailyReadiness[] = [];
  for (let d = 14; d >= 0; d--) {
    const day = addDays(today, -d);
    readiness.push({
      date: day,
      sleepHours: 7 + ((d % 3) - 1) * 0.6,
      hrRest: 47 + (d % 4),
      hrvMs: 78 + ((d % 5) - 2) * 4,
      subjective: { form: 3 + (d % 3), sleepQuality: 3 + (d % 3), soreness: 3 + (d % 3), motivation: 4 },
    });
  }

  return {
    profile,
    equipment,
    races: [race],
    availability,
    injuries: [],
    unavailabilities: [],
    activities,
    readiness,
    progression: 'balanced',
    settings: defaultSettings(),
    onboardingComplete: true,
    planGeneratedAt: null,
    raceChecklists: {},
  };
}

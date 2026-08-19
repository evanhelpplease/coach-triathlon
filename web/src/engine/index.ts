// Point d'entrée public du moteur TriathlonEngine (portage TypeScript).

// Domaine
export * from './domain/types';
export * from './domain/profile';
export * from './domain/equipment';
export * from './domain/zones';
export * from './domain/session';
export * from './domain/activity';
export * from './domain/unavailability';

// Prédictions — export explicite : `predictTimeSeconds` existe dans plusieurs
// modules (VDOT/Riegel/CSS), donc on ne l'expose que via les namespaces pour
// éviter toute collision de barrel.
export { VDOT, vo2Cost, fractionOfMax, vdot, vdotFromVMA, velocityForVO2, trainingPaces, type TrainingPaces } from './predictions/vdot';
export { Riegel, fittedExponent, RIEGEL_DEFAULT_EXPONENT } from './predictions/riegel';
export { CSS } from './predictions/css';
export { CyclingPowerModel, type CyclingPowerParams } from './predictions/cyclingPower';
export { RacePredictor, raceGoalGap, lowSeconds, highSeconds, type RacePrediction, type RaceGoalGap } from './predictions/racePredictor';

// Zones & charge
export * from './zones/zoneCalculator';
export * from './load/loadModel';

// Périodisation & génération
export * from './periodization/periodizer';
export * from './sessionGeneration/plannedLoad';
export * from './sessionGeneration/sessionGenerator';

// Adaptation
export * from './adaptation/readinessEvaluator';
export * from './adaptation/equipmentSubstitution';
export * from './adaptation/adapter';

// Planification
export * from './planning/planBuilder';
export * from './planning/testSessions';

// Analyse & stratégie
export * from './analysis/postSessionAnalyzer';
export * from './analysis/personalRecords';
export * from './analysis/polarization';
export * from './raceStrategy/raceStrategy';

// Utilitaires de date
export * from './util/dates';

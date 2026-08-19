import { describe, it, expect } from 'vitest';
import {
  VDOT,
  vdot,
  trainingPaces,
  Riegel,
  CSS,
  CyclingPowerModel,
  RacePredictor,
  makeProfile,
  makeEquipment,
} from '../index';

const vdotPredict = VDOT.predictTimeSeconds;

describe('VDOT (Daniels)', () => {
  it('5 km 20:00 → VDOT ≈ 49.8', () => {
    expect(vdot(5000, 1200)).toBeCloseTo(49.8, 0); // ±0.7 → tolérance à l'entier
    expect(Math.abs(vdot(5000, 1200) - 49.8)).toBeLessThanOrEqual(0.7);
  });

  it('aller-retour temps ↔ VDOT', () => {
    const v = vdot(5000, 1200);
    expect(Math.abs(vdotPredict(v, 5000) - 1200)).toBeLessThanOrEqual(3);
  });

  it('distance plus longue = plus lente (>2× le 5 km)', () => {
    const t5 = vdotPredict(50, 5000);
    const t10 = vdotPredict(50, 10000);
    expect(t10).toBeGreaterThan(2 * t5);
  });

  it('allures monotones (facile > marathon > seuil > interval > répétition)', () => {
    const p = trainingPaces(50);
    expect(p.easySecPerKm).toBeGreaterThan(p.marathonSecPerKm);
    expect(p.marathonSecPerKm).toBeGreaterThan(p.thresholdSecPerKm);
    expect(p.thresholdSecPerKm).toBeGreaterThan(p.intervalSecPerKm);
    expect(p.intervalSecPerKm).toBeGreaterThan(p.repetitionSecPerKm);
  });

  it('VDOT plus élevé = plus rapide', () => {
    expect(vdotPredict(60, 10000)).toBeLessThan(vdotPredict(40, 10000));
  });

  it('expose un namespace VDOT', () => {
    expect(VDOT.vdot(5000, 1200)).toBeCloseTo(vdot(5000, 1200), 6);
  });
});

describe('Riegel', () => {
  it('5 km 20:00 → 10 km ≈ 41:42 (2502 s)', () => {
    const t = Riegel.predictTimeSeconds(5000, 1200, 10000);
    expect(Math.abs(t - 2502)).toBeLessThanOrEqual(5);
  });

  it('fittedExponent retrouve 1.06', () => {
    const t2 = 1200 * Math.pow(2.0, 1.06);
    expect(Riegel.fittedExponent(5000, 1200, 10000, t2)).toBeCloseTo(1.06, 6);
  });
});

describe('CSS (natation)', () => {
  it('400/6:00 & 200/2:50 → CSS ≈ 1:35/100m (95 s)', () => {
    const pace = CSS.pacePer100m(400, 360, 200, 170);
    expect(Math.abs(pace - 95)).toBeLessThanOrEqual(0.5);
  });

  it('prédit ~380 s au 400 m', () => {
    expect(Math.abs(CSS.predictTimeSeconds(95, 400) - 380)).toBeLessThanOrEqual(1);
  });
});

describe('Modèle puissance vélo', () => {
  const model = (cda = 0.32, mass = 83) => new CyclingPowerModel({ totalMassKg: mass, cda });

  it('40 km @ 250 W plausible (58–75 min)', () => {
    const t = model().predictTimeSeconds(40000, 250);
    expect(t).toBeGreaterThan(58 * 60);
    expect(t).toBeLessThan(75 * 60);
  });

  it('puissance ↑ ⇒ vitesse ↑', () => {
    expect(model().speed(200)).toBeLessThan(model().speed(300));
  });

  it('CdA plus bas = plus rapide', () => {
    expect(model(0.32).speed(250)).toBeLessThan(model(0.24).speed(250));
  });

  it('aller-retour puissance ↔ vitesse', () => {
    const m = model();
    const v = m.speed(250);
    expect(m.power(v)).toBeCloseTo(250, 0);
  });

  it('ordre des CdA typiques : CLM+aéro < route < VTT', () => {
    expect(CyclingPowerModel.typicalCdA('tt', true)).toBeLessThan(CyclingPowerModel.typicalCdA('road', false));
    expect(CyclingPowerModel.typicalCdA('road', false)).toBeLessThan(CyclingPowerModel.typicalCdA('mtb', false));
  });
});

describe('Prédiction de course assemblée', () => {
  const fullProfile = () =>
    makeProfile({
      birthDate: new Date(Date.UTC(1990, 0, 1)),
      sex: 'male',
      heightCm: 180,
      weightKg: 72,
      hrMax: 190,
      hrRest: 48,
      ftpWatts: 260,
      cssSecPer100m: 95,
      vdot: 52,
    });

  it('olympique plausible (2h–2h45) et somme des splits = total', () => {
    const eq = makeEquipment({ hasBike: true, bikeType: 'road', bikeWeightKg: 8, hasAeroBars: true });
    const p = new RacePredictor().predict('olympic', fullProfile(), eq);
    expect(p.swimSeconds).not.toBeNull();
    expect(p.bikeSeconds).not.toBeNull();
    expect(p.totalSeconds).toBeGreaterThan(2 * 3600);
    expect(p.totalSeconds).toBeLessThan(2.75 * 3600);
    const sum = (p.swimSeconds ?? 0) + (p.t1Seconds ?? 0) + (p.bikeSeconds ?? 0) + (p.t2Seconds ?? 0) + p.runSeconds;
    expect(sum).toBeCloseTo(p.totalSeconds, 1);
  });

  it("l'intervalle de confiance s'élargit quand des référentiels manquent", () => {
    const eq = makeEquipment({ hasBike: true, bikeType: 'road' });
    const full = new RacePredictor().predict('olympic', fullProfile(), eq);
    const sparse = makeProfile({ birthDate: new Date(Date.UTC(1990, 0, 1)), sex: 'male', heightCm: 180, weightKg: 72 });
    const poor = new RacePredictor().predict('olympic', sparse, eq);
    expect(poor.confidenceHalfWidth).toBeGreaterThan(full.confidenceHalfWidth);
  });

  it('format mono-sport : pas de nat ni vélo', () => {
    const p = new RacePredictor().predict('marathon', fullProfile(), makeEquipment());
    expect(p.swimSeconds).toBeNull();
    expect(p.bikeSeconds).toBeNull();
    expect(p.runSeconds).toBeCloseTo(p.totalSeconds, 1);
  });

  it('la combinaison accélère la natation', () => {
    const noSuit = makeEquipment({ hasBike: true, bikeType: 'road', hasWetsuit: false });
    const suit = makeEquipment({ hasBike: true, bikeType: 'road', hasWetsuit: true });
    const a = new RacePredictor().predict('olympic', fullProfile(), noSuit);
    const b = new RacePredictor().predict('olympic', fullProfile(), suit);
    expect(b.swimSeconds ?? 0).toBeLessThan(a.swimSeconds ?? 0);
  });
});

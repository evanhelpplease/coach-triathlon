import { describe, it, expect } from 'vitest';
import {
  ZoneCalculator,
  LoadCalculator,
  LoadSeries,
  makeProfile,
  makeActivity,
} from '../index';

describe('ZoneCalculator', () => {
  it('Karvonen : Z2 borne basse = 145.2 (réserve 140)', () => {
    const zones = new ZoneCalculator().hrZones(190, 50);
    const z2 = zones.find((z) => z.zone === 2)!;
    expect(z2.lower).toBeCloseTo(145.2, 1);
    expect(z2.upper).toBeCloseTo(50 + 0.83 * 140, 1);
    expect(zones.at(-1)!.upper).toBe(Infinity);
  });

  it('Coggan : Z4 = 225–262.5 W, 7 zones', () => {
    const z = new ZoneCalculator().powerZones(250);
    const z4 = z.find((x) => x.zone === 4)!;
    expect(z4.lower).toBeCloseTo(225, 2);
    expect(z4.upper).toBeCloseTo(262.5, 2);
    expect(z.length).toBe(7);
  });

  it('source estimée quand FC inconnue, zones quand même remplies', () => {
    const p = makeProfile({ birthDate: new Date(Date.UTC(1990, 0, 1)), sex: 'male', heightCm: 180, weightKg: 72, ftpWatts: 250, vdot: 50 });
    const z = new ZoneCalculator().zones(p);
    expect(z.source).toBe('estimated');
    expect(z.hr.length).toBeGreaterThan(0);
    expect(z.power.length).toBeGreaterThan(0);
    expect(z.runPace.length).toBeGreaterThan(0);
  });

  it('allures course : zone 5 plus rapide (valeur plus basse) que zone 1', () => {
    const z = new ZoneCalculator().runPaceZones(50);
    expect(z.find((x) => x.zone === 5)!.lower).toBeLessThan(z.find((x) => x.zone === 1)!.lower);
  });
});

describe('LoadModel', () => {
  it('1 h @ FTP → TSS = 100', () => {
    expect(new LoadCalculator().cyclingTSS(3600, 250, 250)).toBeCloseTo(100, 2);
  });

  it('1 h au seuil (allure) → TSS = 100', () => {
    expect(new LoadCalculator().paceTSS(3600, 4.0, 4.0)).toBeCloseTo(100, 2);
  });

  it('intensité moindre → TSS moindre', () => {
    const hard = new LoadCalculator().paceTSS(3600, 4.0, 4.0);
    const easy = new LoadCalculator().paceTSS(3600, 3.0, 4.0);
    expect(easy).toBeLessThan(hard);
  });

  it('charge constante 50 → CTL 50, ATL 50, TSB 0, ACWR 1.0', () => {
    const start = new Date(0);
    const days = Array.from({ length: 200 }, (_, i) => ({ date: new Date(i * 86_400_000), load: 50 }));
    const series = new LoadSeries().series(days);
    const last = series.at(-1)!;
    expect(last.ctl).toBeCloseTo(50, 0);
    expect(last.atl).toBeCloseTo(50, 0);
    expect(Math.abs(last.tsb)).toBeLessThanOrEqual(1);
    expect(last.acwr).toBeCloseTo(1.0, 2);
    void start;
  });

  it('dispatch de charge : vélo utilise la puissance (TSS 100)', () => {
    const profile = makeProfile({ birthDate: new Date(Date.UTC(1990, 0, 1)), sex: 'male', heightCm: 180, weightKg: 72, ftpWatts: 250 });
    const a = makeActivity({ sport: 'bike', start: new Date(), duration: 3600, normalizedPowerW: 250 });
    expect(new LoadCalculator().load(a, profile)).toBeCloseTo(100, 0);
  });
});

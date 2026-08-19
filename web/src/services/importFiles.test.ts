import { describe, it, expect } from 'vitest';
import { parseActivityFile } from './importFiles';

// Construit un fichier FIT minimal valide : 1 message de définition (session,
// global 18) + 1 message de données, sans CRC (le parseur ignore la fin).
function buildFitSession(): Uint8Array {
  const fields: Array<{ num: number; size: number; base: number }> = [
    { num: 253, size: 4, base: 6 }, // timestamp uint32
    { num: 2, size: 4, base: 6 }, // start_time uint32
    { num: 7, size: 4, base: 6 }, // total_elapsed_time uint32 (scale 1000)
    { num: 9, size: 4, base: 6 }, // total_distance uint32 (scale 100)
    { num: 5, size: 1, base: 0 }, // sport enum
    { num: 16, size: 1, base: 2 }, // avg_heart_rate uint8
    { num: 20, size: 2, base: 4 }, // avg_power uint16
  ];

  const FIT_EPOCH = 631_065_600_000;
  const startUnix = Date.UTC(2024, 5, 1, 8, 0, 0);
  const startFit = (startUnix - FIT_EPOCH) / 1000;

  const defBody: number[] = [0 /*reserved*/, 0 /*arch LE*/, 18 & 0xff, (18 >> 8) & 0xff, fields.length];
  for (const f of fields) defBody.push(f.num, f.size, f.base);
  const defRecord = [0x40, ...defBody]; // header 0x40 = définition local 0

  const dataBytes: number[] = [];
  const u32 = (v: number) => [v & 0xff, (v >> 8) & 0xff, (v >> 16) & 0xff, (v >>> 24) & 0xff];
  const u16 = (v: number) => [v & 0xff, (v >> 8) & 0xff];
  dataBytes.push(...u32(startFit)); // timestamp
  dataBytes.push(...u32(startFit)); // start_time
  dataBytes.push(...u32(3600 * 1000)); // 1 h
  dataBytes.push(...u32(10_000 * 100)); // 10 km
  dataBytes.push(2); // sport = cycling → bike
  dataBytes.push(145); // avg hr
  dataBytes.push(...u16(210)); // avg power
  const dataRecord = [0x00, ...dataBytes]; // header 0x00 = données local 0

  const payload = [...defRecord, ...dataRecord];
  const header = [12, 0x10, 0xd0, 0x07, ...u32(payload.length), 0x2e, 0x46, 0x49, 0x54]; // ".FIT", dataSize = payload
  return new Uint8Array([...header, ...payload]);
}

describe('Import de fichiers', () => {
  it('FIT : extrait le résumé de session', async () => {
    const bytes = buildFitSession();
    const file = new File([bytes as unknown as BlobPart], 'ride.fit');
    const acts = await parseActivityFile(file);
    expect(acts.length).toBe(1);
    const a = acts[0];
    expect(a.sport).toBe('bike');
    expect(a.duration).toBeCloseTo(3600, 0);
    expect(a.distanceM).toBeCloseTo(10_000, 0);
    expect(a.avgHr).toBe(145);
    expect(a.avgPowerW).toBe(210);
    expect(a.start.getTime()).toBe(Date.UTC(2024, 5, 1, 8, 0, 0));
    expect(a.source).toBe('garmin');
  });

  it('CSV : parse un résumé Garmin Connect', async () => {
    const csv = [
      'Activity Type,Date,Distance,Time,Avg HR,Max HR,Avg Power',
      'Running,2024-06-02 07:30:00,8.00,00:40:00,150,172,',
      'Cycling,2024-06-03 18:00:00,30.00,01:00:00,140,165,205',
    ].join('\n');
    const file = new File([csv], 'activities.csv');
    const acts = await parseActivityFile(file);
    expect(acts.length).toBe(2);
    expect(acts[0].sport).toBe('run');
    expect(acts[0].distanceM).toBeCloseTo(8000, 0);
    expect(acts[0].duration).toBeCloseTo(2400, 0);
    expect(acts[0].avgPaceSecPerKm).toBeCloseTo(300, 0); // 40 min / 8 km = 5:00/km
    expect(acts[1].sport).toBe('bike');
    expect(acts[1].avgPowerW).toBe(205);
  });

  it('rejette un format inconnu', async () => {
    await expect(parseActivityFile(new File(['x'], 'a.txt'))).rejects.toThrow();
  });
});

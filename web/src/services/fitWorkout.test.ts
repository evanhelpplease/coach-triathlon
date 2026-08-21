import { describe, it, expect } from 'vitest';
import { buildFitWorkout } from './fitWorkout';
import { SessionGenerator, ZoneCalculator, makeProfile, makeEquipment } from '@engine/index';

// Table CRC-16 FIT (identique à l'encodeur) pour revérifier indépendamment.
const T = [0x0000, 0xcc01, 0xd801, 0x1400, 0xf001, 0x3c00, 0x2800, 0xe401, 0xa001, 0x6c00, 0x7800, 0xb401, 0x5000, 0x9c01, 0x8801, 0x4400];
function crc(bytes: number[]): number {
  let c = 0;
  for (const b of bytes) {
    let t = T[c & 0xf];
    c = ((c >> 4) & 0x0fff) ^ t ^ T[b & 0xf];
    t = T[c & 0xf];
    c = ((c >> 4) & 0x0fff) ^ t ^ T[(b >> 4) & 0xf];
  }
  return c & 0xffff;
}

/** Compte les messages de données d'un global donné en parcourant le flux FIT. */
function countGlobal(bytes: Uint8Array, target: number): number {
  const view = new DataView(bytes.buffer);
  const headerSize = bytes[0];
  const dataSize = view.getUint32(4, true);
  const defs: Record<number, { global: number; size: number }> = {};
  let pos = headerSize;
  const end = headerSize + dataSize;
  let count = 0;
  while (pos < end) {
    const h = bytes[pos++];
    const local = h & 0x0f;
    if (h & 0x40) {
      // définition
      const global = view.getUint16(pos + 2, true);
      const n = bytes[pos + 4];
      let size = 0;
      let o = pos + 5;
      for (let i = 0; i < n; i++) { size += bytes[o + 1]; o += 3; }
      defs[local] = { global, size };
      pos = o;
    } else {
      const def = defs[local];
      if (def.global === target) count++;
      pos += def.size;
    }
  }
  return count;
}

describe('Export Garmin .FIT', () => {
  const profile = makeProfile({ birthDate: new Date(Date.UTC(1995, 0, 1)), sex: 'male', heightCm: 178, weightKg: 71, hrMax: 190, hrRest: 48, ftpWatts: 255, cssSecPer100m: 96, vdot: 51 });
  const equip = makeEquipment({ hasBike: true, bikeType: 'road', poolAccess: true, runOutdoor: true });
  const zones = new ZoneCalculator().zones(profile);
  const session = new SessionGenerator().generate('bike', 'threshold', 'build', new Date(0), zones, profile, equip);

  const bytes = buildFitWorkout(session);
  const arr = Array.from(bytes);

  it('en-tête .FIT et taille de données cohérentes', () => {
    expect(bytes[0]).toBe(12);
    expect(String.fromCharCode(bytes[8], bytes[9], bytes[10], bytes[11])).toBe('.FIT');
    const view = new DataView(bytes.buffer);
    const dataSize = view.getUint32(4, true);
    expect(dataSize).toBe(bytes.length - 12 - 2);
  });

  it('CRC valide', () => {
    const body = arr.slice(0, arr.length - 2);
    const stored = arr[arr.length - 2] | (arr[arr.length - 1] << 8);
    expect(crc(body)).toBe(stored);
  });

  it('un file_id, un workout, et N workout_step = pas aplatis', () => {
    expect(countGlobal(bytes, 0)).toBe(1); // file_id
    expect(countGlobal(bytes, 26)).toBe(1); // workout
    const view = new DataView(bytes.buffer);
    // num_valid_steps est le champ uint16 juste après sport (1 octet) dans le message workout.
    const nSteps = countGlobal(bytes, 27);
    expect(nSteps).toBeGreaterThan(0);
    // Cohérence : bloc 3× seuil vélo → warmup + 3×(work+recovery) + cooldown = 8 pas.
    expect(nSteps).toBe(8);
    void view;
  });
});

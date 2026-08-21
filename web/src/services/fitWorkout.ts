// Export d'une séance structurée au format Garmin .FIT (fichier "workout"),
// importable dans Garmin Connect → Entraînements → Importer, puis synchronisé
// sur la montre. Les blocs répétés sont « aplatis » (chaque répétition = un pas)
// pour une compatibilité maximale.
import type { PlannedSession, Sport, WorkoutStep } from '@engine/index';

const FIT_EPOCH = 631_065_600; // 1989-12-31T00:00:00Z en secondes
const INVALID_U32 = 0xffffffff;

// Table CRC-16 FIT.
const CRC_TABLE = [0x0000, 0xcc01, 0xd801, 0x1400, 0xf001, 0x3c00, 0x2800, 0xe401, 0xa001, 0x6c00, 0x7800, 0xb401, 0x5000, 0x9c01, 0x8801, 0x4400];
function fitCrc(bytes: number[]): number {
  let crc = 0;
  for (const b of bytes) {
    let tmp = CRC_TABLE[crc & 0xf];
    crc = ((crc >> 4) & 0x0fff) ^ tmp ^ CRC_TABLE[b & 0xf];
    tmp = CRC_TABLE[crc & 0xf];
    crc = ((crc >> 4) & 0x0fff) ^ tmp ^ CRC_TABLE[(b >> 4) & 0xf];
  }
  return crc & 0xffff;
}

class ByteWriter {
  bytes: number[] = [];
  u8(v: number) { this.bytes.push(v & 0xff); }
  u16(v: number) { this.u8(v); this.u8(v >> 8); }
  u32(v: number) { this.u8(v); this.u8(v >> 8); this.u8(v >> 16); this.u8(v >>> 24); }
  str(s: string, size: number) {
    const enc = new TextEncoder().encode(s);
    for (let i = 0; i < size; i++) this.u8(i < enc.length ? enc[i] : 0);
  }
}

type FieldDef = [num: number, size: number, base: number];
function writeDef(w: ByteWriter, local: number, global: number, fields: FieldDef[]): void {
  w.u8(0x40 | local); // header : message de définition
  w.u8(0); // reserved
  w.u8(0); // architecture little-endian
  w.u16(global);
  w.u8(fields.length);
  for (const [num, size, base] of fields) {
    w.u8(num);
    w.u8(size);
    w.u8(base);
  }
}

function sportEnum(sport: Sport): number {
  switch (sport) {
    case 'run': return 1;
    case 'bike': return 2;
    case 'swim': return 5;
    case 'strength': return 10;
    case 'brick': return 1;
  }
}

interface FlatStep {
  intensity: number; // 0 active, 1 rest, 2 warmup, 3 cooldown
  durType: number; // 0 time, 1 distance
  durVal: number; // ms ou cm
  targetType: number; // 0 speed, 1 hr, 2 open, 4 power
  targetValue: number;
  low: number;
  high: number;
}

function mapStep(step: WorkoutStep): FlatStep {
  const intensity =
    step.kind === 'warmup' ? 2 : step.kind === 'cooldown' ? 3 : step.kind === 'recovery' || step.kind === 'rest' ? 1 : 0;

  let durType = 0;
  let durVal = 0;
  if (step.duration.kind === 'time') {
    durType = 0;
    durVal = Math.round(step.duration.seconds * 1000);
  } else if (step.duration.kind === 'distance') {
    durType = 1;
    durVal = Math.round(step.duration.meters * 100);
  } else {
    durType = 1;
    durVal = Math.round(step.duration.count * step.duration.poolMeters * 100);
  }

  const t = step.target;
  let targetType = 2;
  let targetValue = INVALID_U32;
  let low = INVALID_U32;
  let high = INVALID_U32;
  if (t.kind === 'powerRange') {
    targetType = 4;
    targetValue = 0;
    low = Math.round(t.lowW) + 1000; // watts, offset 1000
    high = Math.round(t.highW) + 1000;
  } else if (t.kind === 'paceRange') {
    targetType = 0; // vitesse (mm/s)
    targetValue = 0;
    low = Math.round(1e6 / t.highSecPerKm); // borne basse = plus lente
    high = Math.round(1e6 / t.lowSecPerKm);
  } else if (t.kind === 'swimPaceRange') {
    targetType = 0;
    targetValue = 0;
    low = Math.round(1e5 / t.highSecPer100m);
    high = Math.round(1e5 / t.lowSecPer100m);
  } else if (t.kind === 'hrZone') {
    targetType = 1;
    targetValue = t.zone; // zone FC configurée sur la montre
  } else {
    targetType = 2; // open
    targetValue = 0;
  }
  return { intensity, durType, durVal, targetType, targetValue, low, high };
}

function flatten(session: PlannedSession): FlatStep[] {
  const out: FlatStep[] = [];
  for (const st of session.steps) {
    if (st.kind === 'repeatBlock' && st.children) {
      const reps = st.repeats ?? 1;
      for (let i = 0; i < reps; i++) for (const c of st.children) out.push(mapStep(c));
    } else {
      out.push(mapStep(st));
    }
  }
  return out;
}

export function buildFitWorkout(session: PlannedSession): Uint8Array {
  const steps = flatten(session);
  const name = session.title.slice(0, 30);
  const nameSize = new TextEncoder().encode(name).length + 1; // + null

  const data = new ByteWriter();

  // file_id (global 0)
  writeDef(data, 0, 0, [[0, 1, 0x00], [1, 2, 0x84], [4, 4, 0x86]]);
  data.u8(0x00);
  data.u8(5); // type = workout
  data.u16(255); // manufacturer = development
  data.u32(Math.max(0, Math.round(Date.now() / 1000) - FIT_EPOCH));

  // workout (global 26)
  writeDef(data, 1, 26, [[4, 1, 0x00], [6, 2, 0x84], [8, nameSize, 0x07]]);
  data.u8(0x01);
  data.u8(sportEnum(session.sport));
  data.u16(steps.length);
  data.str(name, nameSize);

  // workout_step (global 27)
  writeDef(data, 2, 27, [
    [254, 2, 0x84], [1, 1, 0x00], [2, 4, 0x86], [3, 1, 0x00], [4, 4, 0x86], [5, 4, 0x86], [6, 4, 0x86], [7, 1, 0x00],
  ]);
  steps.forEach((s, i) => {
    data.u8(0x02);
    data.u16(i);
    data.u8(s.durType);
    data.u32(s.durVal);
    data.u8(s.targetType);
    data.u32(s.targetValue);
    data.u32(s.low);
    data.u32(s.high);
    data.u8(s.intensity);
  });

  const header = new ByteWriter();
  header.u8(12); // taille de l'en-tête
  header.u8(0x20); // protocole 2.0
  header.u16(2140); // version de profil
  header.u32(data.bytes.length);
  header.str('.FIT', 4);

  const all = [...header.bytes, ...data.bytes];
  const crc = fitCrc(all);
  all.push(crc & 0xff, (crc >> 8) & 0xff);
  return new Uint8Array(all);
}

export function downloadFitWorkout(session: PlannedSession): void {
  const bytes = buildFitWorkout(session);
  const blob = new Blob([bytes as unknown as BlobPart], { type: 'application/octet-stream' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = `${session.title.replace(/[^\w]+/g, '_')}.fit`;
  a.click();
  URL.revokeObjectURL(url);
}

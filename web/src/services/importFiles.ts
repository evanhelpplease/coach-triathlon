// Import de fichiers d'activité exportés (Garmin Connect, Strava…) :
// .TCX / .GPX (XML), .CSV (résumé), .FIT (binaire, résumé de session).
// Évite de tout ressaisir dans le Journal. Aucune dépendance externe.
import type { CompletedActivity, Sport } from '@engine/index';

export type ParsedActivity = Omit<CompletedActivity, 'id'>;

function sportFromText(t: string | null | undefined): Sport {
  const s = (t ?? '').toLowerCase();
  if (s.includes('run') || s.includes('cours')) return 'run';
  if (s.includes('bik') || s.includes('cycl') || s.includes('vélo') || s.includes('velo')) return 'bike';
  if (s.includes('swim') || s.includes('nat')) return 'swim';
  if (s.includes('strength') || s.includes('renfo') || s.includes('muscu')) return 'strength';
  return 'run';
}

function mean(xs: number[]): number | undefined {
  return xs.length ? xs.reduce((a, b) => a + b, 0) / xs.length : undefined;
}

function haversine(a: { lat: number; lon: number }, b: { lat: number; lon: number }): number {
  const R = 6_371_000;
  const dLat = ((b.lat - a.lat) * Math.PI) / 180;
  const dLon = ((b.lon - a.lon) * Math.PI) / 180;
  const la1 = (a.lat * Math.PI) / 180;
  const la2 = (b.lat * Math.PI) / 180;
  const h = Math.sin(dLat / 2) ** 2 + Math.cos(la1) * Math.cos(la2) * Math.sin(dLon / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(h));
}

function build(sport: Sport, start: Date, duration: number, opts: Partial<ParsedActivity> = {}): ParsedActivity {
  const distanceM = opts.distanceM;
  const avgPaceSecPerKm = sport === 'run' && distanceM && distanceM > 0 ? duration / (distanceM / 1000) : opts.avgPaceSecPerKm;
  return { sport, start, duration, distanceM, avgPaceSecPerKm, source: 'garmin', ...opts };
}

// --- TCX ---
function parseTcx(text: string): ParsedActivity[] {
  const doc = new DOMParser().parseFromString(text, 'application/xml');
  const activities = Array.from(doc.getElementsByTagName('Activity'));
  const out: ParsedActivity[] = [];
  for (const act of activities) {
    const sport = sportFromText(act.getAttribute('Sport'));
    const tps = Array.from(act.getElementsByTagName('Trackpoint'));
    if (tps.length < 2) continue;
    const times = tps.map((t) => t.getElementsByTagName('Time')[0]?.textContent).filter(Boolean).map((s) => new Date(s!));
    const start = times[0];
    const duration = (times.at(-1)!.getTime() - start.getTime()) / 1000;
    const dists = tps.map((t) => parseFloat(t.getElementsByTagName('DistanceMeters')[0]?.textContent ?? 'NaN')).filter((n) => Number.isFinite(n));
    const distanceM = dists.length ? Math.max(...dists) : undefined;
    const hrs = tps.map((t) => parseInt(t.getElementsByTagName('HeartRateBpm')[0]?.getElementsByTagName('Value')[0]?.textContent ?? '')).filter((n) => Number.isFinite(n));
    const watts = tps.map((t) => parseFloat(t.getElementsByTagName('Watts')[0]?.textContent ?? '')).filter((n) => Number.isFinite(n));
    out.push(build(sport, start, duration, {
      distanceM,
      avgHr: hrs.length ? Math.round(mean(hrs)!) : undefined,
      maxHr: hrs.length ? Math.max(...hrs) : undefined,
      avgPowerW: watts.length ? Math.round(mean(watts)!) : undefined,
    }));
  }
  return out;
}

// --- GPX ---
function parseGpx(text: string, filename: string): ParsedActivity[] {
  const doc = new DOMParser().parseFromString(text, 'application/xml');
  const pts = Array.from(doc.getElementsByTagName('trkpt'));
  if (pts.length < 2) return [];
  const coords = pts.map((p) => ({ lat: parseFloat(p.getAttribute('lat') ?? '0'), lon: parseFloat(p.getAttribute('lon') ?? '0') }));
  const times = pts.map((p) => p.getElementsByTagName('time')[0]?.textContent).filter(Boolean).map((s) => new Date(s!));
  let distanceM = 0;
  for (let i = 1; i < coords.length; i++) distanceM += haversine(coords[i - 1], coords[i]);
  const hrs: number[] = [];
  for (const p of pts) {
    const hr = p.getElementsByTagName('gpxtpx:hr')[0]?.textContent ?? p.getElementsByTagName('hr')[0]?.textContent;
    if (hr) hrs.push(parseInt(hr));
  }
  const start = times[0] ?? new Date();
  const duration = times.length >= 2 ? (times.at(-1)!.getTime() - start.getTime()) / 1000 : 0;
  const nameSport = sportFromText(doc.getElementsByTagName('type')[0]?.textContent ?? filename);
  return [build(nameSport, start, duration, {
    distanceM: Math.round(distanceM),
    avgHr: hrs.length ? Math.round(mean(hrs)!) : undefined,
    maxHr: hrs.length ? Math.max(...hrs) : undefined,
  })];
}

// --- CSV (résumé Garmin Connect / générique) ---
function parseDurationText(s: string): number {
  // "00:45:12" ou "45:12" ou "45.2" (min)
  const parts = s.split(':').map((x) => parseFloat(x));
  if (parts.length === 3) return parts[0] * 3600 + parts[1] * 60 + parts[2];
  if (parts.length === 2) return parts[0] * 60 + parts[1];
  return (parseFloat(s) || 0) * 60;
}

function parseCsv(text: string): ParsedActivity[] {
  const rows = text.trim().split(/\r?\n/).map((r) => r.split(',').map((c) => c.replace(/^"|"$/g, '').trim()));
  if (rows.length < 2) return [];
  const header = rows[0].map((h) => h.toLowerCase());
  const col = (...names: string[]) => header.findIndex((h) => names.some((n) => h.includes(n)));
  const iType = col('activity type', 'type');
  const iDate = col('date', 'start');
  const iDist = col('distance');
  const iTime = col('time', 'duration', 'temps', 'durée');
  const iHr = col('avg hr', 'average heart', 'fc moy');
  const iMaxHr = col('max hr', 'fc max');
  const iPow = col('avg power', 'puissance moy');
  const out: ParsedActivity[] = [];
  for (const row of rows.slice(1)) {
    if (row.length < 2) continue;
    const sport = sportFromText(iType >= 0 ? row[iType] : undefined);
    const start = iDate >= 0 && row[iDate] ? new Date(row[iDate]) : new Date();
    if (isNaN(start.getTime())) continue;
    const duration = iTime >= 0 ? parseDurationText(row[iTime]) : 0;
    const distKm = iDist >= 0 ? parseFloat(row[iDist].replace(',', '.')) : NaN;
    out.push(build(sport, start, duration, {
      distanceM: Number.isFinite(distKm) ? distKm * 1000 : undefined,
      avgHr: iHr >= 0 && row[iHr] ? parseInt(row[iHr]) || undefined : undefined,
      maxHr: iMaxHr >= 0 && row[iMaxHr] ? parseInt(row[iMaxHr]) || undefined : undefined,
      avgPowerW: iPow >= 0 && row[iPow] ? parseInt(row[iPow]) || undefined : undefined,
    }));
  }
  return out;
}

// --- FIT (binaire) : extrait le(s) message(s) session (global 18) ---
const FIT_EPOCH = 631_065_600_000; // 1989-12-31T00:00:00Z en ms
const BASE_SIZE: Record<number, number> = { 0: 1, 1: 1, 2: 1, 3: 2, 4: 2, 5: 4, 6: 4, 7: 1, 8: 4, 9: 8, 10: 1, 11: 2, 12: 4, 13: 1, 14: 8, 15: 8, 16: 8 };
const FIT_SPORT: Record<number, Sport> = { 1: 'run', 2: 'bike', 5: 'swim', 4: 'strength', 10: 'strength' };

interface FitFieldDef { num: number; size: number; base: number; }
interface FitDef { global: number; arch: number; fields: FitFieldDef[]; devBytes: number; }

function parseFit(buf: ArrayBuffer): ParsedActivity[] {
  const view = new DataView(buf);
  const bytes = new Uint8Array(buf);
  const headerSize = view.getUint8(0);
  const dataSize = view.getUint32(4, true);
  let pos = headerSize;
  const end = Math.min(headerSize + dataSize, bytes.length);
  const defs: Record<number, FitDef> = {};
  const sessions: Array<Record<number, number>> = [];

  const readNum = (offset: number, size: number, base: number, arch: number): number => {
    const little = arch === 0;
    if (size === 1) return view.getUint8(offset);
    if (size === 2) return base === 3 ? view.getInt16(offset, little) : view.getUint16(offset, little);
    if (size === 4) return base === 5 ? view.getInt32(offset, little) : base === 8 ? view.getFloat32(offset, little) : view.getUint32(offset, little);
    return NaN; // 8 octets / strings : ignorés pour le résumé
  };

  while (pos < end) {
    const header = bytes[pos];
    pos += 1;
    const isDef = (header & 0x40) !== 0 && (header & 0x80) === 0;
    const local = (header & 0x80) !== 0 ? (header >> 5) & 0x03 : header & 0x0f;

    if (isDef) {
      const arch = bytes[pos + 1];
      const global = view.getUint16(pos + 2, arch === 0);
      const numFields = bytes[pos + 4];
      pos += 5;
      const fields: FitFieldDef[] = [];
      for (let i = 0; i < numFields; i++) {
        fields.push({ num: bytes[pos], size: bytes[pos + 1], base: bytes[pos + 2] & 0x1f });
        pos += 3;
      }
      let devBytes = 0;
      if ((header & 0x20) !== 0) {
        const numDev = bytes[pos];
        pos += 1;
        for (let i = 0; i < numDev; i++) {
          devBytes += bytes[pos + 1];
          pos += 3;
        }
      }
      defs[local] = { global, arch, fields, devBytes };
    } else {
      const def = defs[local];
      if (!def) break; // flux corrompu
      const msgStart = pos;
      const values: Record<number, number> = {};
      let o = msgStart;
      for (const f of def.fields) {
        if (def.global === 18) {
          const size = BASE_SIZE[f.base] ?? f.size;
          if (size === f.size || f.size <= 4) values[f.num] = readNum(o, f.size, f.base, def.arch);
        }
        o += f.size;
      }
      pos = msgStart + def.fields.reduce((s, f) => s + f.size, 0) + def.devBytes;
      if (def.global === 18) sessions.push(values);
    }
  }

  return sessions
    .map((s) => {
      const startRaw = s[2] ?? s[253];
      if (startRaw == null || !Number.isFinite(startRaw)) return null;
      const start = new Date(FIT_EPOCH + startRaw * 1000);
      const duration = s[7] != null ? s[7] / 1000 : 0;
      const distanceM = s[9] != null ? s[9] / 100 : undefined;
      const sport = FIT_SPORT[s[5]] ?? 'run';
      return build(sport, start, duration, {
        distanceM,
        avgHr: s[16] || undefined,
        maxHr: s[17] || undefined,
        avgPowerW: s[20] || undefined,
        normalizedPowerW: s[34] || undefined,
      });
    })
    .filter((x): x is ParsedActivity => x !== null && x.duration > 0);
}

/** Dispatch par extension. Renvoie les activités prêtes à ajouter au Journal. */
export async function parseActivityFile(file: File): Promise<ParsedActivity[]> {
  const name = file.name.toLowerCase();
  if (name.endsWith('.fit')) return parseFit(await file.arrayBuffer());
  const text = await file.text();
  if (name.endsWith('.tcx')) return parseTcx(text);
  if (name.endsWith('.gpx')) return parseGpx(text, name);
  if (name.endsWith('.csv')) return parseCsv(text);
  throw new Error('Format non reconnu (.fit, .tcx, .gpx, .csv).');
}

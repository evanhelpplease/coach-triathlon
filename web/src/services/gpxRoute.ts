// Parcours vélo GPX road-snappés via OpenRouteService (clé API gratuite).
// Profil « cycling-road » : privilégie les routes revêtues roulantes / pistes.
// - Boucle d'une distance cible (endurance, sorties longues).
// - Aller-retour via un point remarquable (Bois de Vincennes, Longchamp) pour
//   rejoindre un circuit connu et y placer les intervalles.
const ORS = 'https://api.openrouteservice.org';
const PROFILE = 'cycling-road';

export type LonLat = [number, number];

/** Points de repère parisiens pour les intervalles ([lon, lat] ; ORS route vers la route la plus proche). */
export const LANDMARKS: Record<string, { label: string; coord: LonLat }> = {
  vincennes: { label: 'Bois de Vincennes (anneau)', coord: [2.4342, 48.8307] },
  longchamp: { label: 'Longchamp (boucle)', coord: [2.2337, 48.856] },
};

async function orsFetch(path: string, apiKey: string, body: unknown): Promise<string> {
  const res = await fetch(`${ORS}${path}`, {
    method: 'POST',
    headers: { Authorization: apiKey, 'Content-Type': 'application/json', Accept: 'application/gpx+xml, application/json' },
    body: JSON.stringify(body),
  });
  if (!res.ok) {
    let detail = '';
    try {
      detail = (await res.json())?.error?.message ?? '';
    } catch {
      /* ignore */
    }
    if (res.status === 403 || res.status === 401) throw new Error('Clé OpenRouteService invalide ou quota dépassé.');
    throw new Error(`Routage impossible (${res.status}) ${detail}`.trim());
  }
  return res.text();
}

/** Géocode l'adresse de départ → [lon, lat]. */
export async function geocode(apiKey: string, address: string): Promise<LonLat> {
  const url = `${ORS}/geocode/search?api_key=${encodeURIComponent(apiKey)}&text=${encodeURIComponent(address)}&boundary.country=FR&size=1`;
  const res = await fetch(url);
  if (!res.ok) throw new Error(res.status === 403 || res.status === 401 ? 'Clé OpenRouteService invalide.' : `Géocodage impossible (${res.status}).`);
  const json = await res.json();
  const c = json?.features?.[0]?.geometry?.coordinates;
  if (!Array.isArray(c) || c.length < 2) throw new Error('Adresse de départ introuvable.');
  return [c[0], c[1]];
}

/** Boucle d'une longueur cible (m) au départ de `start`, renvoyée en GPX. */
export async function roundTripGpx(apiKey: string, start: LonLat, lengthM: number): Promise<string> {
  return orsFetch(`/v2/directions/${PROFILE}/gpx`, apiKey, {
    coordinates: [start],
    options: { round_trip: { length: Math.round(lengthM), points: 4, seed: Math.floor(Math.random() * 1000) } },
  });
}

/** Aller-retour start → point remarquable → start, en GPX. */
export async function viaGpx(apiKey: string, start: LonLat, via: LonLat): Promise<string> {
  return orsFetch(`/v2/directions/${PROFILE}/gpx`, apiKey, {
    coordinates: [start, via, start],
  });
}

export function downloadGpx(gpx: string, name: string): void {
  const blob = new Blob([gpx], { type: 'application/gpx+xml' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = `${name.replace(/[^\w]+/g, '_')}.gpx`;
  a.click();
  URL.revokeObjectURL(url);
}

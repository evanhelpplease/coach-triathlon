// Météo via Open-Meteo (gratuit, sans clé). Portage de App/Weather/WeatherService.swift.
import type { Sport } from '@engine/index';

export interface Weather {
  temperatureC: number;
  precipitationMm: number;
  windKmh: number;
  code: number;
  description: string;
}

function describe(code: number): string {
  if (code === 0) return 'Ciel dégagé';
  if (code <= 2) return 'Peu nuageux';
  if (code === 3) return 'Couvert';
  if (code <= 48) return 'Brouillard';
  if (code <= 57) return 'Bruine';
  if (code <= 67) return 'Pluie';
  if (code <= 77) return 'Neige';
  if (code <= 82) return 'Averses';
  if (code <= 99) return 'Orage';
  return 'Variable';
}

const PARIS = { lat: 48.8566, lon: 2.3522 };

export async function getPosition(): Promise<{ lat: number; lon: number }> {
  return new Promise((resolve) => {
    if (!('geolocation' in navigator)) return resolve(PARIS);
    navigator.geolocation.getCurrentPosition(
      (p) => resolve({ lat: p.coords.latitude, lon: p.coords.longitude }),
      () => resolve(PARIS),
      { timeout: 6000, maximumAge: 3_600_000 },
    );
  });
}

export async function fetchWeather(pos?: { lat: number; lon: number }): Promise<Weather | null> {
  const { lat, lon } = pos ?? (await getPosition());
  const url = `https://api.open-meteo.com/v1/forecast?latitude=${lat}&longitude=${lon}&current=temperature_2m,precipitation,weather_code,wind_speed_10m`;
  try {
    const res = await fetch(url);
    if (!res.ok) return null;
    const json = await res.json();
    const c = json.current;
    return {
      temperatureC: c.temperature_2m,
      precipitationMm: c.precipitation,
      windKmh: c.wind_speed_10m,
      code: c.weather_code,
      description: describe(c.weather_code),
    };
  } catch {
    return null;
  }
}

/** Suggère extérieur ↔ home trainer / tapis selon les conditions. */
export function indoorSuggestion(w: Weather, sport: Sport): string | null {
  if (sport !== 'bike' && sport !== 'run') return null;
  if (w.precipitationMm > 0.5) return sport === 'bike' ? 'Pluie : home trainer conseillé.' : 'Pluie : tapis ou vêtements adaptés.';
  if (w.windKmh > 35 && sport === 'bike') return 'Vent fort : home trainer plus confortable.';
  if (w.temperatureC <= 1) return 'Gel : prudence dehors, intérieur possible.';
  if (w.temperatureC >= 32) return 'Forte chaleur : tôt le matin ou en intérieur, hydrate-toi.';
  return 'Conditions OK pour l\'extérieur.';
}

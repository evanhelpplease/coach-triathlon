// Helpers de formatage (français, unités métriques).
import type { Sport, SessionIntent } from '@engine/index';

export function hms(seconds: number): string {
  const t = Math.round(seconds);
  const h = Math.trunc(t / 3600);
  const m = Math.trunc((t % 3600) / 60);
  if (h > 0) return `${h} h ${String(m).padStart(2, '0')}`;
  return `${m} min`;
}

export function mmss(seconds: number): string {
  const s = Math.round(seconds);
  return `${Math.trunc(s / 60)}:${String(s % 60).padStart(2, '0')}`;
}

/** Chrono h:mm:ss (ou mm:ss si < 1 h) pour un objectif de course. */
export function clock(seconds: number): string {
  const s = Math.round(seconds);
  const h = Math.trunc(s / 3600);
  const m = Math.trunc((s % 3600) / 60);
  const sec = s % 60;
  return h > 0 ? `${h}:${String(m).padStart(2, '0')}:${String(sec).padStart(2, '0')}` : `${m}:${String(sec).padStart(2, '0')}`;
}

/** Parse « h:mm:ss » ou « mm:ss » → secondes (null si vide/invalide). */
export function parseClock(str: string): number | null {
  const t = str.trim();
  if (!t) return null;
  const parts = t.split(':').map((x) => parseInt(x, 10));
  if (parts.some((n) => Number.isNaN(n))) return null;
  if (parts.length === 3) return parts[0] * 3600 + parts[1] * 60 + parts[2];
  if (parts.length === 2) return parts[0] * 60 + parts[1];
  if (parts.length === 1) return parts[0] * 60; // minutes seules
  return null;
}

export function paceKm(secPerKm: number): string {
  return `${mmss(secPerKm)}/km`;
}

export function pace100(secPer100: number): string {
  return `${mmss(secPer100)}/100m`;
}

export function km(meters: number): string {
  return `${(meters / 1000).toFixed(1)} km`;
}

const DAYS = ['dim.', 'lun.', 'mar.', 'mer.', 'jeu.', 'ven.', 'sam.'];
const MONTHS = ['janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', 'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'];

export function dateFr(d: Date): string {
  return `${DAYS[d.getDay()]} ${d.getDate()} ${MONTHS[d.getMonth()]}`;
}

export function dateShort(d: Date): string {
  return `${d.getDate()} ${MONTHS[d.getMonth()]}`;
}

export function sportEmoji(sport: Sport): string {
  switch (sport) {
    case 'swim': return '🏊';
    case 'bike': return '🚴';
    case 'run': return '🏃';
    case 'strength': return '💪';
    case 'brick': return '🔁';
  }
}

export function sportLabel(sport: Sport): string {
  switch (sport) {
    case 'swim': return 'Natation';
    case 'bike': return 'Vélo';
    case 'run': return 'Course';
    case 'strength': return 'Renforcement';
    case 'brick': return 'Brick';
  }
}

export function sportColor(sport: Sport): string {
  switch (sport) {
    case 'swim': return 'var(--swim)';
    case 'bike': return 'var(--bike)';
    case 'run': return 'var(--run)';
    case 'strength': return 'var(--strength)';
    case 'brick': return 'var(--accent)';
  }
}

export function intentLabel(intent: SessionIntent): string {
  switch (intent) {
    case 'recovery': return 'Récupération';
    case 'endurance': return 'Endurance';
    case 'tempo': return 'Tempo';
    case 'threshold': return 'Seuil';
    case 'vo2': return 'VO2max';
    case 'sprint': return 'Sprint';
    case 'technique': return 'Technique';
    case 'brick': return 'Brick';
    case 'strength': return 'Force';
  }
}

export function daysUntil(d: Date, from: Date = new Date()): number {
  const ms = new Date(d.getFullYear(), d.getMonth(), d.getDate()).getTime() - new Date(from.getFullYear(), from.getMonth(), from.getDate()).getTime();
  return Math.round(ms / 86_400_000);
}

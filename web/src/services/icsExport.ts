// Export du plan au format iCalendar (.ics), importable dans Google Agenda,
// Apple Calendrier, Outlook… sans OAuth ni API. Alternative simple à la synchro.
import type { PlannedSession, Race, WorkoutStep } from '@engine/index';
import { hms, intentLabel, sportEmoji, sportLabel } from '../ui/format';

const FORMAT_LABEL: Record<string, string> = {
  xs: 'XS', sprint: 'Sprint', olympic: 'Olympique (M)', half: 'Half 70.3', full: 'Full 140.6',
  run10k: '10 km', halfMarathon: 'Semi', marathon: 'Marathon',
};

function pad(n: number): string {
  return String(n).padStart(2, '0');
}
/** Heure « flottante » locale : l'événement s'affiche à cette heure quel que soit le fuseau. */
function localDateTime(d: Date): string {
  return `${d.getFullYear()}${pad(d.getMonth() + 1)}${pad(d.getDate())}T${pad(d.getHours())}${pad(d.getMinutes())}00`;
}
function dateOnly(d: Date): string {
  return `${d.getFullYear()}${pad(d.getMonth() + 1)}${pad(d.getDate())}`;
}
function stampUTC(d: Date): string {
  return `${d.getUTCFullYear()}${pad(d.getUTCMonth() + 1)}${pad(d.getUTCDate())}T${pad(d.getUTCHours())}${pad(d.getUTCMinutes())}${pad(d.getUTCSeconds())}Z`;
}
function esc(s: string): string {
  return s.replace(/\\/g, '\\\\').replace(/;/g, '\\;').replace(/,/g, '\\,').replace(/\r?\n/g, '\\n');
}

function stepLine(step: WorkoutStep): string {
  if (step.kind === 'repeatBlock' && step.children) {
    const inner = step.children
      .map((c) => (c.duration.kind === 'time' ? `${Math.round(c.duration.seconds / 60)}′` : ''))
      .filter(Boolean)
      .join(' / ');
    return `${step.repeats ?? 1}× (${inner}) ${step.children[0]?.cue ?? ''}`.trim();
  }
  const dur =
    step.duration.kind === 'time'
      ? `${Math.round(step.duration.seconds / 60)}′`
      : step.duration.kind === 'lengths'
        ? `${step.duration.count}×${step.duration.poolMeters}m`
        : `${(step.duration.meters / 1000).toFixed(1)}km`;
  return `${step.kind} ${dur}${step.cue ? ' — ' + step.cue : ''}`;
}

function sessionEvent(s: PlannedSession, now: Date): string[] {
  const start = new Date(s.date);
  start.setHours(7, 0, 0, 0); // créneau par défaut 07:00 (déplaçable dans l'agenda)
  const end = new Date(start.getTime() + Math.max(1800, s.estimatedDuration) * 1000);
  const desc = [
    `${intentLabel(s.intent)} · charge estimée ${Math.round(s.estimatedLoad)}`,
    ...s.steps.map(stepLine),
    s.notes,
    '— Coach Triathlon IA',
  ].filter(Boolean).join('\n');
  return [
    'BEGIN:VEVENT',
    `UID:${s.id}@coachtriathlon`,
    `DTSTAMP:${stampUTC(now)}`,
    `DTSTART:${localDateTime(start)}`,
    `DTEND:${localDateTime(end)}`,
    `SUMMARY:${esc(`${sportEmoji(s.sport)} ${sportLabel(s.sport)} — ${intentLabel(s.intent)} (${hms(s.estimatedDuration)})`)}`,
    `DESCRIPTION:${esc(desc)}`,
    'END:VEVENT',
  ];
}

function raceEvent(r: Race, now: Date): string[] {
  const next = new Date(r.date);
  next.setDate(next.getDate() + 1);
  return [
    'BEGIN:VEVENT',
    `UID:${r.id}@coachtriathlon`,
    `DTSTAMP:${stampUTC(now)}`,
    `DTSTART;VALUE=DATE:${dateOnly(r.date)}`,
    `DTEND;VALUE=DATE:${dateOnly(next)}`,
    `SUMMARY:${esc(`🏁 ${r.title}`)}`,
    `DESCRIPTION:${esc(`Course ${FORMAT_LABEL[r.format] ?? r.format} · priorité ${r.priority.toUpperCase()}${r.goalTimeSeconds ? ` · objectif ${hms(r.goalTimeSeconds)}` : ''}`)}`,
    'END:VEVENT',
  ];
}

export function buildICS(sessions: PlannedSession[], races: Race[]): string {
  const now = new Date();
  const lines = [
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    'PRODID:-//Coach Triathlon IA//FR',
    'CALSCALE:GREGORIAN',
    'METHOD:PUBLISH',
    'X-WR-CALNAME:Coach Triathlon IA',
    ...sessions.flatMap((s) => sessionEvent(s, now)),
    ...races.flatMap((r) => raceEvent(r, now)),
    'END:VCALENDAR',
  ];
  return lines.join('\r\n');
}

export function downloadICS(sessions: PlannedSession[], races: Race[]): void {
  const blob = new Blob([buildICS(sessions, races)], { type: 'text/calendar;charset=utf-8' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = `coach-triathlon-${new Date().toISOString().slice(0, 10)}.ics`;
  a.click();
  URL.revokeObjectURL(url);
}

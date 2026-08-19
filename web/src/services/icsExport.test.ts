import { describe, it, expect } from 'vitest';
import { buildICS } from './icsExport';
import { makePlannedSession, makeRace, addDays, startOfDay } from '@engine/index';

describe('Export .ics', () => {
  const start = startOfDay(new Date(0));
  const sessions = [
    makePlannedSession({ date: addDays(start, 1), sport: 'run', intent: 'threshold', title: 'Course — seuil', estimatedDuration: 3600, estimatedLoad: 70 }),
    makePlannedSession({ date: addDays(start, 2), sport: 'swim', intent: 'endurance', title: 'Natation — endurance', estimatedDuration: 2400, estimatedLoad: 30 }),
  ];
  const races = [makeRace({ date: addDays(start, 30), format: 'olympic', priority: 'a', title: 'Triathlon M', goalTimeSeconds: 7500 })];

  it('produit un calendrier valide avec un VEVENT par séance et par course', () => {
    const ics = buildICS(sessions, races);
    expect(ics.startsWith('BEGIN:VCALENDAR')).toBe(true);
    expect(ics.trimEnd().endsWith('END:VCALENDAR')).toBe(true);
    expect((ics.match(/BEGIN:VEVENT/g) ?? []).length).toBe(3);
    expect((ics.match(/END:VEVENT/g) ?? []).length).toBe(3);
    expect(ics).toContain('UID:');
    expect(ics).toContain('SUMMARY:');
  });

  it('les courses sont des événements « toute la journée »', () => {
    const ics = buildICS(sessions, races);
    expect(ics).toContain('DTSTART;VALUE=DATE:');
    expect(ics).toContain('🏁 Triathlon M');
  });

  it('échappe les caractères spéciaux (virgules, points-virgules)', () => {
    const r = [makeRace({ date: start, format: 'olympic', priority: 'a', title: 'Triathlon, du lac; test' })];
    const ics = buildICS([], r);
    expect(ics).toContain('Triathlon\\, du lac\\; test');
  });
});

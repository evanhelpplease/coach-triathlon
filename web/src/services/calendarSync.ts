// Synchro Google Agenda : OAuth navigateur via Google Identity Services (GIS)
// + Calendar API REST. Scope RESTREINT `calendar.app.created` : l'app ne peut
// gérer QUE le calendrier dédié qu'elle crée elle-même — elle ne voit ni ne
// modifie tes autres événements. Idempotent via extendedProperties.private.coachtriId.
//
// Prérequis (docs/GOOGLE_CALENDAR.md) : projet Google Cloud, Calendar API activée,
// OAuth client ID (Web) avec l'origine GitHub Pages, Client ID renseigné en Réglages.
import type { PlannedSession } from '@engine/index';
import { hms, intentLabel, sportEmoji, sportLabel } from '../ui/format';

// Scope restreint : gestion uniquement des calendriers/événements créés par l'app.
const SCOPE = 'https://www.googleapis.com/auth/calendar.app.created';
const GIS_SRC = 'https://accounts.google.com/gsi/client';
const CAL_BASE = 'https://www.googleapis.com/calendar/v3';
const CALENDAR_SUMMARY = 'Coach Triathlon IA';

interface TokenClient {
  requestAccessToken: (opts?: { prompt?: string }) => void;
}

declare global {
  interface Window {
    google?: {
      accounts: {
        oauth2: {
          initTokenClient: (cfg: { client_id: string; scope: string; callback: (r: { access_token?: string; error?: string }) => void }) => TokenClient;
        };
      };
    };
  }
}

let gisLoaded: Promise<void> | null = null;
function loadGis(): Promise<void> {
  if (gisLoaded) return gisLoaded;
  gisLoaded = new Promise((resolve, reject) => {
    if (window.google?.accounts) return resolve();
    const s = document.createElement('script');
    s.src = GIS_SRC;
    s.async = true;
    s.defer = true;
    s.onload = () => resolve();
    s.onerror = () => reject(new Error('Chargement de Google Identity Services impossible.'));
    document.head.appendChild(s);
  });
  return gisLoaded;
}

let accessToken: string | null = null;

/** Demande (ou renouvelle) un jeton d'accès. Interactif la première fois. */
export async function connectGoogle(clientId: string): Promise<void> {
  await loadGis();
  const oauth2 = window.google!.accounts.oauth2;
  await new Promise<void>((resolve, reject) => {
    const client = oauth2.initTokenClient({
      client_id: clientId,
      scope: SCOPE,
      callback: (resp) => {
        if (resp.error || !resp.access_token) return reject(new Error(resp.error ?? 'Autorisation refusée.'));
        accessToken = resp.access_token;
        resolve();
      },
    });
    client.requestAccessToken({ prompt: '' });
  });
}

export function isConnected(): boolean {
  return accessToken != null;
}

function sessionDescription(s: PlannedSession): string {
  const lines: string[] = [`${intentLabel(s.intent)} · charge estimée ${Math.round(s.estimatedLoad)}`];
  for (const step of s.steps) {
    if (step.kind === 'repeatBlock' && step.children) {
      const inner = step.children.map((c) => (c.duration.kind === 'time' ? `${Math.round(c.duration.seconds / 60)}′` : '')).join(' / ');
      lines.push(`${step.repeats ?? 1}× (${inner}) ${step.children[0]?.cue ?? ''}`);
    } else {
      const dur =
        step.duration.kind === 'time'
          ? `${Math.round(step.duration.seconds / 60)}′`
          : step.duration.kind === 'lengths'
            ? `${step.duration.count}×${step.duration.poolMeters}m`
            : `${Math.round((step.duration.meters ?? 0) / 100) / 10}km`;
      lines.push(`${step.kind} ${dur}${step.cue ? ' — ' + step.cue : ''}`);
    }
  }
  if (s.notes) lines.push(`\n${s.notes}`);
  lines.push('\n— Coach Triathlon IA');
  return lines.join('\n');
}

function eventBody(s: PlannedSession): Record<string, unknown> {
  const start = new Date(s.date);
  start.setHours(7, 0, 0, 0); // créneau par défaut 07:00 (déplaçable)
  const end = new Date(start.getTime() + Math.max(1800, s.estimatedDuration) * 1000);
  return {
    summary: `${sportEmoji(s.sport)} ${sportLabel(s.sport)} — ${intentLabel(s.intent)} (${hms(s.estimatedDuration)})`,
    description: sessionDescription(s),
    start: { dateTime: start.toISOString() },
    end: { dateTime: end.toISOString() },
    extendedProperties: { private: { coachtriId: s.id } },
  };
}

async function gfetch(path: string, init?: RequestInit): Promise<Response> {
  return fetch(`${CAL_BASE}${path}`, {
    ...init,
    headers: { Authorization: `Bearer ${accessToken}`, 'Content-Type': 'application/json', ...(init?.headers ?? {}) },
  });
}

/** Garantit le calendrier dédié : réutilise l'ID connu (s'il existe encore), sinon en crée un. */
async function ensureCalendar(existingId?: string): Promise<string> {
  if (existingId) {
    const res = await gfetch(`/calendars/${encodeURIComponent(existingId)}`);
    if (res.ok) return existingId;
  }
  const tz = Intl.DateTimeFormat().resolvedOptions().timeZone || 'Europe/Paris';
  const res = await gfetch('/calendars', {
    method: 'POST',
    body: JSON.stringify({ summary: CALENDAR_SUMMARY, description: 'Séances générées par Coach Triathlon IA.', timeZone: tz }),
  });
  if (!res.ok) throw new Error('Création du calendrier dédié impossible.');
  const cal = (await res.json()) as { id: string };
  return cal.id;
}

export interface SyncReport {
  created: number;
  updated: number;
  deleted: number;
  failed: number;
}

/**
 * Crée/met à jour un événement par séance dans le calendrier dédié (idempotent
 * via coachtriId). Renvoie l'ID du calendrier pour le persister côté app.
 */
export async function syncSessions(
  sessions: PlannedSession[],
  existingCalendarId?: string,
): Promise<{ report: SyncReport; calendarId: string }> {
  if (!accessToken) throw new Error('Non connecté à Google Agenda.');
  const calendarId = await ensureCalendar(existingCalendarId);
  const cal = encodeURIComponent(calendarId);
  const report: SyncReport = { created: 0, updated: 0, deleted: 0, failed: 0 };

  for (const s of sessions) {
    try {
      const search = await gfetch(`/calendars/${cal}/events?privateExtendedProperty=${encodeURIComponent('coachtriId=' + s.id)}&maxResults=1&showDeleted=false`);
      const found = search.ok ? (((await search.json()).items as Array<{ id: string }>) ?? []) : [];
      const body = JSON.stringify(eventBody(s));
      if (found.length > 0) {
        const res = await gfetch(`/calendars/${cal}/events/${found[0].id}`, { method: 'PUT', body });
        res.ok ? report.updated++ : report.failed++;
      } else {
        const res = await gfetch(`/calendars/${cal}/events`, { method: 'POST', body });
        res.ok ? report.created++ : report.failed++;
      }
    } catch {
      report.failed++;
    }
  }

  // Miroir du plan : supprime les événements du futur qui ne sont plus dans le
  // plan (ex. séances vélo/natation retirées après un changement de matériel).
  await deleteOrphans(cal, new Set(sessions.map((s) => s.id)), report);

  return { report, calendarId };
}

async function deleteOrphans(cal: string, currentIds: Set<string>, report: SyncReport): Promise<void> {
  const midnight = new Date();
  midnight.setHours(0, 0, 0, 0);
  try {
    let pageToken: string | undefined;
    do {
      const url = `/calendars/${cal}/events?timeMin=${encodeURIComponent(midnight.toISOString())}&singleEvents=true&maxResults=250${pageToken ? `&pageToken=${encodeURIComponent(pageToken)}` : ''}`;
      const res = await gfetch(url);
      if (!res.ok) break;
      const data = (await res.json()) as {
        items?: Array<{ id: string; extendedProperties?: { private?: { coachtriId?: string } } }>;
        nextPageToken?: string;
      };
      for (const ev of data.items ?? []) {
        const cid = ev.extendedProperties?.private?.coachtriId;
        if (cid && !currentIds.has(cid)) {
          const del = await gfetch(`/calendars/${cal}/events/${ev.id}`, { method: 'DELETE' });
          if (del.ok) report.deleted++;
        }
      }
      pageToken = data.nextPageToken;
    } while (pageToken);
  } catch {
    /* nettoyage best-effort */
  }
}

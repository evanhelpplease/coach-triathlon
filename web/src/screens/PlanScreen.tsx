import { useMemo, useState } from 'react';
import { Link } from 'react-router-dom';
import { addDays, startOfDay, type Race, type TrainingPhase } from '@engine/index';
import { useStore } from '../app/store';
import { planWeekLoad } from '@engine/index';
import { Card, SectionTitle, SessionRow, Pill, EmptyState } from '../ui/components';
import { dateShort, dateFr } from '../ui/format';
import { syncSessions, connectGoogle } from '../services/calendarSync';
import { downloadICS } from '../services/icsExport';

const FORMAT_SHORT: Record<string, string> = {
  xs: 'XS', sprint: 'Sprint', olympic: 'M', half: '70.3', full: '140.6', run10k: '10 km', halfMarathon: 'Semi', marathon: 'Marathon',
};

function RaceRow({ race }: { race: Race }) {
  return (
    <Link to={`/race/${race.id}`} style={{ textDecoration: 'none', color: 'inherit', display: 'block' }}>
      <div
        className="session"
        style={{ borderColor: 'var(--accent)', background: 'color-mix(in srgb, var(--accent) 12%, var(--surface))' }}
      >
        <div className="badge" style={{ background: 'color-mix(in srgb, var(--accent) 30%, transparent)' }}>🏁</div>
        <div className="grow">
          <div className="title" style={{ color: 'var(--accent)' }}>{race.title}</div>
          <div className="sub">JOUR DE COURSE · {FORMAT_SHORT[race.format]}{race.priority === 'a' ? ' · objectif A' : ''} — voir la prépa →</div>
        </div>
        <div className="tertiary small">{dateFr(race.date)}</div>
      </div>
    </Link>
  );
}

const PHASE_LABEL: Record<TrainingPhase, string> = {
  base: 'Base', build: 'Build', specific: 'Spécifique', taper: 'Affûtage', recovery: 'Récupération',
};
const PHASE_COLOR: Record<TrainingPhase, string> = {
  base: 'var(--run)', build: 'var(--bike)', specific: 'var(--primary)', taper: 'var(--accent)', recovery: 'var(--text-tertiary)',
};

export function PlanScreen() {
  const data = useStore((s) => s.data);
  const plan = useStore((s) => s.plan);
  const regenerate = useStore((s) => s.regeneratePlan);
  const update = useStore((s) => s.update);
  const [syncMsg, setSyncMsg] = useState<string | null>(null);
  const today = startOfDay(new Date());

  const weeks = useMemo(() => {
    if (!plan) return [];
    return plan.weeks.map((w) => {
      const end = addDays(w.startDate, 7);
      const sessions = plan.sessions.filter((s) => s.date >= w.startDate && s.date < end);
      const races = data.races.filter((r) => r.date >= w.startDate && r.date < end);
      const items = [
        ...sessions.map((s) => ({ kind: 'session' as const, date: s.date, session: s })),
        ...races.map((r) => ({ kind: 'race' as const, date: r.date, race: r })),
      ].sort((a, b) => a.date.getTime() - b.date.getTime());
      return { week: w, items, load: planWeekLoad(plan, w.index) };
    });
  }, [plan, data.races]);

  async function doSync() {
    if (!plan) return;
    if (!data.settings.googleClientId) {
      setSyncMsg('Renseigne ton Client ID Google dans Réglages pour activer la synchro agenda.');
      return;
    }
    try {
      setSyncMsg('Connexion à Google…');
      await connectGoogle(data.settings.googleClientId);
      const upcoming = plan.sessions.filter((s) => s.date >= today);
      setSyncMsg(`Synchronisation de ${upcoming.length} séances…`);
      const { report, calendarId } = await syncSessions(upcoming, data.settings.googleCalendarId);
      if (calendarId !== data.settings.googleCalendarId) update((d) => { d.settings.googleCalendarId = calendarId; });
      setSyncMsg(`Calendrier « Coach Triathlon IA » synchronisé : ${report.created} créées, ${report.updated} mises à jour, ${report.deleted} retirées${report.failed ? `, ${report.failed} échecs` : ''}.`);
    } catch (e) {
      setSyncMsg(`Échec : ${(e as Error).message}`);
    }
  }

  if (!plan) {
    return (
      <div className="screen">
        <div className="screen-header"><h1>Plan</h1></div>
        <EmptyState title="Pas encore de plan">Ajoute un profil et une course pour générer un plan périodisé.</EmptyState>
      </div>
    );
  }

  return (
    <div className="screen">
      <div className="screen-header">
        <div>
          <h1>Plan</h1>
          <div className="sub">{plan.weeks.length} semaines · {plan.sessions.length} séances</div>
        </div>
      </div>

      <div className="row wrap" style={{ marginBottom: 'var(--sp-sm)' }}>
        <button className="btn" onClick={regenerate}>♻️ Régénérer</button>
        <button className="btn accent" onClick={() => downloadICS(plan.sessions, data.races)}>⬇️ Export agenda (.ics)</button>
        <button className="btn primary" onClick={doSync}>📅 Synchro auto</button>
      </div>
      <div className="tertiary small" style={{ marginBottom: 'var(--sp-sm)' }}>
        .ics : importe le fichier dans Google Agenda (Paramètres → Importer et exporter). « Synchro auto » nécessite un Client ID Google (Réglages).
      </div>
      {syncMsg && <div className="banner" style={{ marginBottom: 'var(--sp-sm)' }}>{syncMsg}</div>}

      {plan.rationale[0] && <Card style={{ marginBottom: 'var(--sp-md)' }}><div className="small muted">{plan.rationale[0]}</div></Card>}

      {weeks.map(({ week, items, load }) => (
        <div key={week.index}>
          <SectionTitle>
            Semaine {week.index + 1} · {dateShort(week.startDate)}
          </SectionTitle>
          <div className="row between" style={{ marginBottom: 'var(--sp-xs)' }}>
            <div className="row" style={{ gap: 6 }}>
              <Pill color={PHASE_COLOR[week.phase]}>{PHASE_LABEL[week.phase]}</Pill>
              {week.isDeload && <Pill color="var(--warning)">Décharge</Pill>}
              {items.some((it) => it.kind === 'race') && <Pill color="var(--accent)">🏁 Course</Pill>}
            </div>
            <span className="tertiary small">charge {Math.round(load)} / cible {week.targetLoad}</span>
          </div>
          {items.length > 0 ? (
            <div className="stack-sm">
              {items.map((it) =>
                it.kind === 'race'
                  ? <RaceRow key={it.race.id} race={it.race} />
                  : <SessionRow key={it.session.id} session={it.session} to={`/session/${it.session.id}`} />,
              )}
            </div>
          ) : (
            <div className="tertiary small">Repos.</div>
          )}
        </div>
      ))}
    </div>
  );
}

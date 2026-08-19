import { useEffect, useMemo, useState } from 'react';
import { Link } from 'react-router-dom';
import { isSameDay, startOfDay } from '@engine/index';
import { useStore } from '../app/store';
import { adaptedPlan, latestLoad, todayReadiness } from '../app/derive';
import { Card, SectionTitle, TSBRing, SessionRow, Banner, Stat, EmptyState, Pill } from '../ui/components';
import { daysUntil, dateFr, hms } from '../ui/format';
import { fetchWeather, indoorSuggestion, type Weather } from '../services/weather';

function CheckinSlider({ label, value, set }: { label: string; value: number; set: (n: number) => void }) {
  return (
    <div style={{ marginBottom: 8 }}>
      <div className="row between small" style={{ marginBottom: 2 }}>
        <span className="muted">{label}</span>
        <b>{value}/5</b>
      </div>
      <input type="range" min={1} max={5} value={value} onChange={(e) => set(parseInt(e.target.value))} style={{ width: '100%' }} />
    </div>
  );
}

/** Check-in du jour : ajuste la séance en direct via le moteur d'adaptation. */
function CheckinCard() {
  const data = useStore((s) => s.data);
  const addReadiness = useStore((s) => s.addReadiness);
  const today = startOfDay(new Date());
  const existing = data.readiness.find((r) => isSameDay(r.date, today));
  const { assessment } = todayReadiness(data);

  const [open, setOpen] = useState(false);
  const [form, setForm] = useState(existing?.subjective?.form ?? 4);
  const [sleepQuality, setSleepQuality] = useState(existing?.subjective?.sleepQuality ?? 4);
  const [soreness, setSoreness] = useState(existing?.subjective?.soreness ?? 4);
  const [motivation, setMotivation] = useState(existing?.subjective?.motivation ?? 4);
  const [sleepHours, setSleepHours] = useState(existing?.sleepHours != null ? String(existing.sleepHours) : '');

  function submit() {
    addReadiness({
      date: today,
      sleepHours: sleepHours ? parseFloat(sleepHours.replace(',', '.')) || undefined : undefined,
      hrRest: existing?.hrRest,
      hrvMs: existing?.hrvMs,
      subjective: { form, sleepQuality, soreness, motivation },
    });
    setOpen(false);
  }

  if (existing?.subjective && !open) {
    const lvl = assessment?.level;
    return (
      <Card>
        <div className="row between">
          <div>
            <div style={{ fontWeight: 600 }}>Check-in du jour ✓</div>
            <div className="tertiary small">
              {lvl === 'good' ? 'Forme au top — on peut y aller.' : lvl === 'moderate' ? 'Forme moyenne — intensité ajustée.' : 'Forme basse — séance allégée.'}
            </div>
          </div>
          <button className="btn ghost small" onClick={() => setOpen(true)}>Modifier</button>
        </div>
      </Card>
    );
  }

  if (!open) {
    return (
      <Card style={{ borderLeft: '3px solid var(--primary)' }}>
        <div className="row between">
          <div>
            <div style={{ fontWeight: 600 }}>Comment te sens-tu aujourd'hui ?</div>
            <div className="tertiary small">30 s de check-in → la séance du jour s'adapte.</div>
          </div>
          <button className="btn primary small" onClick={() => setOpen(true)}>Check-in</button>
        </div>
      </Card>
    );
  }

  return (
    <Card style={{ borderLeft: '3px solid var(--primary)' }}>
      <div style={{ fontWeight: 600, marginBottom: 10 }}>Check-in du jour</div>
      <CheckinSlider label="Forme" value={form} set={setForm} />
      <CheckinSlider label="Qualité du sommeil" value={sleepQuality} set={setSleepQuality} />
      <CheckinSlider label="Courbatures (5 = aucune)" value={soreness} set={setSoreness} />
      <CheckinSlider label="Motivation" value={motivation} set={setMotivation} />
      <div className="field" style={{ marginTop: 8 }}>
        <label>Heures de sommeil (optionnel)</label>
        <input className="input" inputMode="decimal" value={sleepHours} onChange={(e) => setSleepHours(e.target.value)} placeholder="7.5" />
      </div>
      <button className="btn primary block" onClick={submit}>Valider — adapter ma journée</button>
    </Card>
  );
}

export function Cockpit() {
  const data = useStore((s) => s.data);
  const plan = useStore((s) => s.plan);
  const today = startOfDay(new Date());

  const load = useMemo(() => latestLoad(data), [data]);
  const adapt = useMemo(() => adaptedPlan(data, plan), [data, plan]);
  const { assessment } = useMemo(() => todayReadiness(data), [data]);

  const todaySessions = adapt.plan.filter((s) => isSameDay(s.date, today));
  const todayEvents = adapt.events.filter((e) => isSameDay(e.date, today));

  const nextRace = useMemo(
    () => [...data.races].filter((r) => r.date >= today).sort((a, b) => a.date.getTime() - b.date.getTime())[0] ?? null,
    [data.races, today],
  );

  const [weather, setWeather] = useState<Weather | null>(null);
  useEffect(() => {
    void fetchWeather().then(setWeather);
  }, []);

  const weekStats = useMemo(() => {
    const from = new Date(today);
    from.setDate(from.getDate() - ((from.getDay() + 6) % 7)); // lundi
    const acts = data.activities.filter((a) => a.start >= from);
    const durH = acts.reduce((s, a) => s + a.duration, 0) / 3600;
    return { count: acts.length, hours: durH };
  }, [data.activities, today]);

  const greeting = new Date().getHours() < 12 ? 'Bonjour' : new Date().getHours() < 18 ? 'Bon après-midi' : 'Bonsoir';

  return (
    <div className="screen">
      <div className="screen-header">
        <div>
          <h1>{greeting} 👋</h1>
          <div className="sub">{dateFr(today)}</div>
        </div>
        {assessment && (
          <Pill color={assessment.level === 'good' ? 'var(--success)' : assessment.level === 'moderate' ? 'var(--warning)' : 'var(--danger)'}>
            Forme {assessment.level === 'good' ? 'au top' : assessment.level === 'moderate' ? 'moyenne' : 'basse'} · {Math.round(assessment.score)}
          </Pill>
        )}
      </div>

      <Card>
        {load ? (
          <TSBRing tsb={load.tsb} ctl={load.ctl} atl={load.atl} />
        ) : (
          <div className="muted small">Saisis des entraînements dans le Journal pour calculer ta forme (TSB).</div>
        )}
      </Card>

      <CheckinCard />

      {weather && (
        <Card>
          <div className="row between">
            <div>
              <div className="row" style={{ gap: 8 }}>
                <span className="num" style={{ fontSize: '1.5rem' }}>{Math.round(weather.temperatureC)}°</span>
                <span className="muted">{weather.description}</span>
              </div>
              <div className="tertiary small">Vent {Math.round(weather.windKmh)} km/h · pluie {weather.precipitationMm} mm</div>
            </div>
            <span style={{ fontSize: '2rem' }}>{weather.precipitationMm > 0.3 ? '🌧️' : weather.code <= 2 ? '☀️' : '⛅'}</span>
          </div>
          {todaySessions[0] && indoorSuggestion(weather, todaySessions[0].sport) && (
            <div className="banner" style={{ marginTop: 'var(--sp-sm)' }}>{indoorSuggestion(weather, todaySessions[0].sport)}</div>
          )}
        </Card>
      )}

      {todayEvents.length > 0 && (
        <>
          <SectionTitle>Adaptations du jour</SectionTitle>
          {todayEvents.map((e) => (
            <Banner key={e.id} kind={e.kind === 'alert' || e.kind === 'deload' ? 'warning' : e.kind === 'injuryAdjusted' ? 'danger' : 'info'}>
              {e.message}
            </Banner>
          ))}
        </>
      )}

      <SectionTitle>Séance du jour</SectionTitle>
      {todaySessions.length > 0 ? (
        <div className="stack-sm">
          {todaySessions.map((s) => (
            <SessionRow key={s.id} session={s} to={`/session/${s.id}`} />
          ))}
        </div>
      ) : (
        <EmptyState title="Repos aujourd'hui 😌">Profite pour récupérer. Un check-in dans le Journal aide le coach à ajuster demain.</EmptyState>
      )}

      <SectionTitle>Cette semaine</SectionTitle>
      <div className="stat-grid">
        <Stat value={weekStats.count} label="séances" />
        <Stat value={`${weekStats.hours.toFixed(1)} h`} label="volume" />
        <Stat value={load ? Math.round(load.acwr * 100) / 100 : '—'} label="ACWR" color={load && load.acwr > 1.5 ? 'var(--danger)' : undefined} />
      </div>

      <SectionTitle>Prochaine course</SectionTitle>
      {nextRace ? (
        <Link to="/predictions" style={{ textDecoration: 'none', color: 'inherit' }}>
          <Card>
            <div className="row between">
              <div>
                <div style={{ fontWeight: 600 }}>{nextRace.title}</div>
                <div className="muted small">{dateFr(nextRace.date)} · {nextRace.format.toUpperCase()} · priorité {nextRace.priority.toUpperCase()}</div>
              </div>
              <div style={{ textAlign: 'right' }}>
                <div className="num" style={{ fontSize: '1.6rem', color: 'var(--primary)' }}>J−{daysUntil(nextRace.date)}</div>
                <div className="tertiary small">Voir prédiction →</div>
              </div>
            </div>
          </Card>
        </Link>
      ) : (
        <EmptyState title="Aucune course programmée">
          <Link to="/races">Ajoute une course</Link> pour générer un plan périodisé.
        </EmptyState>
      )}

      <div style={{ marginTop: 'var(--sp-md)' }} className="row wrap">
        <Link className="btn ghost" to="/predictions">🔮 Prédictions</Link>
        <Link className="btn ghost" to="/injuries">🩹 Blessures</Link>
        <Link className="btn ghost" to="/races">🏁 Courses</Link>
      </div>
      <div className="tertiary small" style={{ textAlign: 'center', marginTop: 'var(--sp-md)' }}>
        Charge du jour : {hms((todaySessions.reduce((s, x) => s + x.estimatedDuration, 0)))} planifiées
      </div>
    </div>
  );
}

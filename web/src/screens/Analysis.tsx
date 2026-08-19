import { useMemo } from 'react';
import {
  ResponsiveContainer, LineChart, Line, BarChart, Bar, XAxis, YAxis, Tooltip, CartesianGrid, Legend,
} from 'recharts';
import { PostSessionAnalyzer, PersonalRecords, LoadCalculator, startOfDay, type Sport } from '@engine/index';
import { useStore } from '../app/store';
import { loadSeries } from '../app/derive';
import { Card, SectionTitle, EmptyState } from '../ui/components';
import { dateShort, sportColor, sportEmoji, sportLabel } from '../ui/format';

const AXIS = { stroke: '#5e7183', fontSize: 11 };

export function Analysis() {
  const data = useStore((s) => s.data);

  const series = useMemo(() => loadSeries(data), [data]);
  const chartData = useMemo(
    () => series.slice(-90).map((p) => ({ d: dateShort(p.date), tsb: Math.round(p.tsb), ctl: Math.round(p.ctl), atl: Math.round(p.atl) })),
    [series],
  );

  const weekly = useMemo(() => weeklyBySport(data), [data]);

  const records = useMemo(() => (data.profile ? new PersonalRecords().compute(data.activities) : []), [data]);

  const lastAnalysis = useMemo(() => {
    if (!data.profile || data.activities.length === 0) return null;
    const last = [...data.activities].sort((a, b) => b.start.getTime() - a.start.getTime())[0];
    return { activity: last, analysis: new PostSessionAnalyzer().analyze(last, data.profile, data.activities) };
  }, [data]);

  if (!data.profile) {
    return (
      <div className="screen">
        <div className="screen-header"><h1>Analyse</h1></div>
        <EmptyState title="Profil requis">Complète ton profil pour analyser tes séances.</EmptyState>
      </div>
    );
  }

  return (
    <div className="screen">
      <div className="screen-header"><h1>Analyse</h1></div>

      {chartData.length > 2 ? (
        <>
          <SectionTitle>Forme (TSB)</SectionTitle>
          <Card>
            <ResponsiveContainer width="100%" height={180}>
              <LineChart data={chartData} margin={{ top: 6, right: 6, left: -18, bottom: 0 }}>
                <CartesianGrid stroke="#263141" vertical={false} />
                <XAxis dataKey="d" tick={AXIS} interval={Math.ceil(chartData.length / 6)} />
                <YAxis tick={AXIS} />
                <Tooltip contentStyle={{ background: '#131a22', border: '1px solid #263141', borderRadius: 10 }} />
                <Line type="monotone" dataKey="tsb" stroke="#16c0d4" strokeWidth={2} dot={false} name="TSB" />
              </LineChart>
            </ResponsiveContainer>
          </Card>

          <SectionTitle>Fitness & Fatigue</SectionTitle>
          <Card>
            <ResponsiveContainer width="100%" height={180}>
              <LineChart data={chartData} margin={{ top: 6, right: 6, left: -18, bottom: 0 }}>
                <CartesianGrid stroke="#263141" vertical={false} />
                <XAxis dataKey="d" tick={AXIS} interval={Math.ceil(chartData.length / 6)} />
                <YAxis tick={AXIS} />
                <Tooltip contentStyle={{ background: '#131a22', border: '1px solid #263141', borderRadius: 10 }} />
                <Legend wrapperStyle={{ fontSize: 12 }} />
                <Line type="monotone" dataKey="ctl" stroke="#4cd787" strokeWidth={2} dot={false} name="Fitness (CTL)" />
                <Line type="monotone" dataKey="atl" stroke="#ffb23e" strokeWidth={2} dot={false} name="Fatigue (ATL)" />
              </LineChart>
            </ResponsiveContainer>
          </Card>
        </>
      ) : (
        <EmptyState title="Pas assez de données">Enregistre des séances dans le Journal pour voir tes courbes de forme.</EmptyState>
      )}

      {weekly.length > 0 && (
        <>
          <SectionTitle>Charge hebdo par sport</SectionTitle>
          <Card>
            <ResponsiveContainer width="100%" height={190}>
              <BarChart data={weekly} margin={{ top: 6, right: 6, left: -18, bottom: 0 }}>
                <CartesianGrid stroke="#263141" vertical={false} />
                <XAxis dataKey="week" tick={AXIS} />
                <YAxis tick={AXIS} />
                <Tooltip contentStyle={{ background: '#131a22', border: '1px solid #263141', borderRadius: 10 }} />
                <Bar dataKey="swim" stackId="a" fill="#39b7f5" name="Nat" />
                <Bar dataKey="bike" stackId="a" fill="#ff8a50" name="Vélo" />
                <Bar dataKey="run" stackId="a" fill="#4cd787" name="Course" />
                <Bar dataKey="strength" stackId="a" fill="#b48cf0" name="Renfo" />
              </BarChart>
            </ResponsiveContainer>
          </Card>
        </>
      )}

      {lastAnalysis && (
        <>
          <SectionTitle>Dernière séance</SectionTitle>
          <Card>
            <div style={{ fontWeight: 600, marginBottom: 8 }}>{sportEmoji(lastAnalysis.activity.sport)} {lastAnalysis.analysis.headline}</div>
            <div className="stack-sm">
              {lastAnalysis.analysis.insights.map((s, i) => (
                <div key={i} className="small muted">• {s}</div>
              ))}
            </div>
          </Card>
        </>
      )}

      <SectionTitle>Records personnels</SectionTitle>
      {records.length > 0 ? (
        <div className="stack-sm">
          {records.map((r) => (
            <div key={r.sportKey + r.label} className="session">
              <div className="badge" style={{ background: `color-mix(in srgb, ${sportColor(r.sportKey as Sport)} 22%, transparent)` }}>
                {sportEmoji(r.sportKey as Sport)}
              </div>
              <div className="grow">
                <div className="title">{r.value}</div>
                <div className="sub">{sportLabel(r.sportKey as Sport)} · {r.label}</div>
              </div>
            </div>
          ))}
        </div>
      ) : (
        <EmptyState title="Aucun record">Ajoute des séances avec distance/puissance pour établir tes records.</EmptyState>
      )}
    </div>
  );
}

function weeklyBySport(data: ReturnType<typeof useStore.getState>['data']) {
  if (!data.profile) return [];
  const calc = new LoadCalculator();
  const buckets = new Map<string, { week: string; swim: number; bike: number; run: number; strength: number; order: number }>();
  for (const a of data.activities) {
    const monday = startOfDay(a.start);
    monday.setDate(monday.getDate() - ((monday.getDay() + 6) % 7));
    const key = monday.toISOString().slice(0, 10);
    if (!buckets.has(key)) buckets.set(key, { week: dateShort(monday), swim: 0, bike: 0, run: 0, strength: 0, order: monday.getTime() });
    const b = buckets.get(key)!;
    const load = Math.round(calc.load(a, data.profile));
    const sport = a.sport === 'brick' ? 'run' : (a.sport as Exclude<Sport, 'brick'>);
    b[sport] += load;
  }
  return [...buckets.values()].sort((x, y) => x.order - y.order).slice(-8);
}

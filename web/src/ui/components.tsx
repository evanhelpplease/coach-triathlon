import type { ReactNode } from 'react';
import { Link } from 'react-router-dom';
import type { PlannedSession } from '@engine/index';
import { hms, intentLabel, sportColor, sportEmoji, dateFr } from './format';

export function Card({ children, style, className }: { children: ReactNode; style?: React.CSSProperties; className?: string }) {
  return (
    <div className={`card${className ? ' ' + className : ''}`} style={style}>
      {children}
    </div>
  );
}

export function SectionTitle({ children }: { children: ReactNode }) {
  return <div className="section-title">{children}</div>;
}

export function Pill({ children, color }: { children: ReactNode; color?: string }) {
  return <span className="pill" style={color ? { color } : undefined}>{children}</span>;
}

export function Stat({ value, label, color }: { value: ReactNode; label: string; color?: string }) {
  return (
    <div className="stat">
      <div className="v" style={color ? { color } : undefined}>{value}</div>
      <div className="l">{label}</div>
    </div>
  );
}

export function Banner({ children, kind = 'info' }: { children: ReactNode; kind?: 'info' | 'warning' | 'danger' | 'success' }) {
  return <div className={`banner ${kind === 'info' ? '' : kind}`}>{children}</div>;
}

/** Anneau d'état de forme (TSB). */
export function TSBRing({ tsb, ctl, atl }: { tsb: number; ctl: number; atl: number }) {
  const size = 132;
  const stroke = 12;
  const r = (size - stroke) / 2;
  const c = 2 * Math.PI * r;
  // Mappe TSB [-30, +25] → [0, 1].
  const norm = Math.max(0, Math.min(1, (tsb + 30) / 55));
  const color = tsb < -20 ? 'var(--danger)' : tsb < -5 ? 'var(--warning)' : tsb > 15 ? 'var(--primary)' : 'var(--success)';
  return (
    <div style={{ display: 'flex', gap: 'var(--sp-md)', alignItems: 'center' }}>
      <svg width={size} height={size}>
        <circle cx={size / 2} cy={size / 2} r={r} fill="none" stroke="var(--separator)" strokeWidth={stroke} />
        <circle
          cx={size / 2}
          cy={size / 2}
          r={r}
          fill="none"
          stroke={color}
          strokeWidth={stroke}
          strokeLinecap="round"
          strokeDasharray={c}
          strokeDashoffset={c * (1 - norm)}
          transform={`rotate(-90 ${size / 2} ${size / 2})`}
        />
        <text x="50%" y="46%" textAnchor="middle" fill="var(--text-primary)" fontSize="30" fontWeight="700" dominantBaseline="middle">
          {tsb >= 0 ? '+' : ''}{Math.round(tsb)}
        </text>
        <text x="50%" y="64%" textAnchor="middle" fill="var(--text-tertiary)" fontSize="12">
          Forme (TSB)
        </text>
      </svg>
      <div>
        <div className="row" style={{ marginBottom: 6 }}>
          <span className="num" style={{ color: 'var(--primary)' }}>{Math.round(ctl)}</span>
          <span className="muted small">Fitness (CTL)</span>
        </div>
        <div className="row">
          <span className="num" style={{ color: 'var(--warning)' }}>{Math.round(atl)}</span>
          <span className="muted small">Fatigue (ATL)</span>
        </div>
      </div>
    </div>
  );
}

export function SessionRow({ session, to, note, done }: { session: PlannedSession; to?: string; note?: string; done?: boolean }) {
  const body = (
    <div className="session" style={done ? { opacity: 0.68 } : undefined}>
      <div className="badge" style={{ background: `color-mix(in srgb, ${sportColor(session.sport)} 22%, transparent)` }}>
        {sportEmoji(session.sport)}
      </div>
      <div className="grow">
        <div className="title">{session.title}</div>
        <div className="sub">
          {intentLabel(session.intent)} · {hms(session.estimatedDuration)} · charge {Math.round(session.estimatedLoad)}
          {note ? ` · ${note}` : ''}
        </div>
      </div>
      <div className="tertiary small">
        {done && <span style={{ color: 'var(--success)', marginRight: 6 }}>✓ fait</span>}
        {dateFr(session.date)}
      </div>
    </div>
  );
  return to ? <Link to={to} style={{ textDecoration: 'none', color: 'inherit', display: 'block' }}>{body}</Link> : body;
}

export function EmptyState({ title, children }: { title: string; children?: ReactNode }) {
  return (
    <Card>
      <h3 style={{ marginBottom: 6 }}>{title}</h3>
      <div className="muted small">{children}</div>
    </Card>
  );
}

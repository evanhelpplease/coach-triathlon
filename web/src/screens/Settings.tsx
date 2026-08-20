import { useEffect, useRef, useState } from 'react';
import { Link } from 'react-router-dom';
import { makeAvailability, vdotFromVMA, type ProgressionLevel, type BikeType, type Equipment } from '@engine/index';
import { useStore } from '../app/store';
import { Card, SectionTitle, Banner } from '../ui/components';
import { mmss } from '../ui/format';
import { SportDaysEditor, UnavailabilityEditor } from '../ui/planningEditors';
import { canInstall, promptInstall, isStandalone } from '../pwa/install';
import { AuthPanel } from './AuthPanel';

const PROGRESSIONS: { value: ProgressionLevel; label: string; desc: string }[] = [
  { value: 'prudent', label: 'Prudent', desc: 'Montée douce, risque de blessure minimal.' },
  { value: 'balanced', label: 'Équilibré', desc: 'Bon compromis progrès / sécurité.' },
  { value: 'performance', label: 'Performance', desc: 'Montée rapide, plus exigeant.' },
];

export function Settings() {
  const data = useStore((s) => s.data);
  const setProfile = useStore((s) => s.setProfile);
  const setEquipment = useStore((s) => s.setEquipment);
  const setProgression = useStore((s) => s.setProgression);
  const setAvailability = useStore((s) => s.setAvailability);
  const setSettings = useStore((s) => s.setSettings);
  const loadDemo = useStore((s) => s.loadDemo);
  const reset = useStore((s) => s.reset);
  const exportData = useStore((s) => s.exportData);
  const importData = useStore((s) => s.importData);
  const update = useStore((s) => s.update);
  const addUnavailability = useStore((s) => s.addUnavailability);
  const removeUnavailability = useStore((s) => s.removeUnavailability);
  const fileRef = useRef<HTMLInputElement>(null);
  const [clientId, setClientId] = useState(data.settings.googleClientId ?? '');
  const [installable, setInstallable] = useState(canInstall());
  useEffect(() => {
    const on = () => setInstallable(canInstall());
    window.addEventListener('pwa-installable', on);
    window.addEventListener('pwa-installed', on);
    return () => { window.removeEventListener('pwa-installable', on); window.removeEventListener('pwa-installed', on); };
  }, []);

  const p = data.profile;

  return (
    <div className="screen">
      <div className="screen-header"><h1>Réglages ⚙️</h1></div>

      {p && (
        <>
          <SectionTitle>Référentiels physiologiques</SectionTitle>
          <Card>
            <div className="row">
              <div className="field grow"><label>Taille (cm)</label><input className="input" inputMode="numeric" defaultValue={p.heightCm} onBlur={(e) => setProfile({ ...p, heightCm: parseFloat(e.target.value) || p.heightCm })} /></div>
              <div className="field grow"><label>Poids (kg)</label><input className="input" inputMode="decimal" defaultValue={p.weightKg} onBlur={(e) => setProfile({ ...p, weightKg: parseFloat(e.target.value) || p.weightKg })} /></div>
            </div>
            <div className="row">
              <div className="field grow"><label>FC max</label><input className="input" inputMode="numeric" defaultValue={p.hrMax ?? ''} onBlur={(e) => setProfile({ ...p, hrMax: parseInt(e.target.value) || undefined })} /></div>
              <div className="field grow"><label>FC repos</label><input className="input" inputMode="numeric" defaultValue={p.hrRest ?? ''} onBlur={(e) => setProfile({ ...p, hrRest: parseInt(e.target.value) || undefined })} /></div>
            </div>
            <div className="row">
              <div className="field grow"><label>VMA (km/h)</label><input className="input" inputMode="decimal" defaultValue={p.vma ?? ''} onBlur={(e) => { const v = parseFloat(e.target.value); setProfile(v > 0 ? { ...p, vma: v, vdot: vdotFromVMA(v) } : { ...p, vma: undefined }); }} /></div>
              <div className="field grow"><label>VDOT (course)</label><input key={`vdot-${p.vdot ?? ''}`} className="input" inputMode="decimal" defaultValue={p.vdot != null ? p.vdot.toFixed(1) : ''} onBlur={(e) => setProfile({ ...p, vdot: parseFloat(e.target.value) || undefined })} /></div>
            </div>
            <div className="row">
              <div className="field grow"><label>FTP (W)</label><input className="input" inputMode="numeric" defaultValue={p.ftpWatts ?? ''} onBlur={(e) => setProfile({ ...p, ftpWatts: parseInt(e.target.value) || undefined })} /></div>
              <div className="field grow"><label>CSS (s/100m)</label><input className="input" inputMode="numeric" defaultValue={p.cssSecPer100m ?? ''} onBlur={(e) => setProfile({ ...p, cssSecPer100m: parseFloat(e.target.value) || undefined })} /></div>
            </div>
            <div className="tertiary small">VMA renseignée → VDOT recalculé automatiquement. CSS actuel : {p.cssSecPer100m ? mmss(p.cssSecPer100m) + '/100m' : '—'}. Modifs prises en compte au focus perdu.</div>
          </Card>
        </>
      )}

      <SectionTitle>Progression</SectionTitle>
      <div className="stack-sm">
        {PROGRESSIONS.map((pr) => (
          <button key={pr.value} className={`session`} onClick={() => setProgression(pr.value)} style={{ borderColor: data.progression === pr.value ? 'var(--primary)' : undefined }}>
            <div className="grow">
              <div className="title">{pr.label}</div>
              <div className="sub">{pr.desc}</div>
            </div>
            {data.progression === pr.value && <span style={{ color: 'var(--primary)' }}>✓</span>}
          </button>
        ))}
      </div>

      <SectionTitle>Disponibilités</SectionTitle>
      <Card>
        <div className="field">
          <label>Séances max / semaine : <b>{data.availability.maxSessionsPerWeek}</b></label>
          <input type="range" min={3} max={12} value={data.availability.maxSessionsPerWeek}
            onChange={(e) => setAvailability(makeAvailability({ ...data.availability, maxSessionsPerWeek: parseInt(e.target.value) }))}
            style={{ width: '100%' }} />
        </div>
        <div className="field" style={{ marginBottom: 0 }}>
          <label>Longueur du bassin</label>
          <select className="select" value={data.settings.poolMeters} onChange={(e) => setSettings({ poolMeters: parseInt(e.target.value) })}>
            <option value={25}>25 m</option>
            <option value={33}>33 m</option>
            <option value={50}>50 m</option>
          </select>
        </div>
      </Card>

      <SectionTitle>Jours de dispo par discipline</SectionTitle>
      <SportDaysEditor availability={data.availability} onChange={setAvailability} />

      <SectionTitle>Indisponibilités temporaires</SectionTitle>
      <UnavailabilityEditor unavailabilities={data.unavailabilities} onAdd={addUnavailability} onRemove={removeUnavailability} />

      <SectionTitle>Matériel</SectionTitle>
      <EquipmentEditor equipment={data.equipment} onChange={setEquipment} />

      <SectionTitle>Synchro Google Agenda</SectionTitle>
      <Card>
        <div className="field"><label>OAuth Client ID (Web)</label>
          <input className="input" value={clientId} placeholder="…apps.googleusercontent.com" onChange={(e) => setClientId(e.target.value)} onBlur={() => setSettings({ googleClientId: clientId.trim() || undefined })} />
        </div>
        <label className="row between" style={{ padding: '4px 0' }}>
          <span>Resynchroniser à chaque changement de plan</span>
          <input type="checkbox" checked={data.settings.calendarAutoSync} onChange={(e) => setSettings({ calendarAutoSync: e.target.checked })} />
        </label>
        <div className="tertiary small">Accès restreint : l'app crée un calendrier <b>« Coach Triathlon IA »</b> dédié et n'écrit que dedans — elle ne voit ni ne modifie tes autres événements. Prérequis : projet Google Cloud, Calendar API activée, OAuth client ID (Web) avec ton origine GitHub Pages. La synchro se lance depuis l'onglet Plan.</div>
      </Card>

      <SectionTitle>Compte & synchro (multi-appareils)</SectionTitle>
      <AuthPanel />
      <div className="tertiary small" style={{ marginTop: 'var(--sp-xs)' }}>Connecte-toi avec le même compte sur ton téléphone et ton ordinateur pour retrouver le même plan partout.</div>

      <SectionTitle>Données & sauvegarde</SectionTitle>
      <Card>
        <div className="tertiary small" style={{ marginBottom: 10 }}>
          Persistance locale active (cet appareil). Pour le multi-appareils : Firebase (recommandé) ou Google Drive — voir la doc. En attendant, exporte/importe le fichier JSON.
        </div>
        <div className="row wrap">
          <button className="btn" onClick={exportData}>⬇️ Exporter JSON</button>
          <button className="btn" onClick={() => fileRef.current?.click()}>⬆️ Importer JSON</button>
          <button className="btn ghost" onClick={loadDemo}>🎭 Athlète démo</button>
        </div>
        <input ref={fileRef} type="file" accept="application/json" hidden onChange={(e) => { const f = e.target.files?.[0]; if (f) void importData(f); }} />
      </Card>

      <SectionTitle>Application</SectionTitle>
      <Card>
        {isStandalone() ? (
          <div className="tertiary small">✅ App installée sur cet appareil.</div>
        ) : installable ? (
          <>
            <div className="tertiary small" style={{ marginBottom: 10 }}>Installe l'app sur ton écran d'accueil pour un accès rapide, plein écran et hors-ligne.</div>
            <button className="btn primary block" onClick={() => void promptInstall()}>📲 Installer l'app</button>
          </>
        ) : (
          <div className="tertiary small">
            Pour installer : sur Android/Chrome, menu ⋮ → « Installer l'application ». Sur iPhone (Safari), bouton Partager → « Sur l'écran d'accueil ».
          </div>
        )}
      </Card>

      <SectionTitle>Compte</SectionTitle>
      <Card>
        <div className="row wrap">
          <button className="btn ghost" onClick={() => update((d) => { d.onboardingComplete = false; })}>↩️ Refaire l'onboarding</button>
          <button className="btn ghost danger" onClick={() => { if (confirm('Effacer toutes les données locales ?')) reset(); }}>🗑️ Tout effacer</button>
        </div>
      </Card>

      <Banner>Reto : <Link to="/">Cockpit</Link> · Le moteur (calcul pur) est testé sur les valeurs de référence Daniels/Coggan/Banister.</Banner>
    </div>
  );
}

function Toggle({ label, value, onChange }: { label: string; value: boolean; onChange: (v: boolean) => void }) {
  return (
    <label className="row between" style={{ padding: '8px 0', borderBottom: '1px solid var(--separator)' }}>
      <span>{label}</span>
      <input type="checkbox" checked={value} onChange={(e) => onChange(e.target.checked)} />
    </label>
  );
}

/** Matériel groupé par discipline. */
function EquipmentEditor({ equipment, onChange }: { equipment: Equipment; onChange: (e: Equipment) => void }) {
  const set = (patch: Partial<Equipment>) => onChange({ ...equipment, ...patch });
  return (
    <Card>
      <div className="section-title" style={{ marginTop: 0 }}>🚴 Vélo</div>
      <Toggle label="J'ai un vélo" value={equipment.hasBike} onChange={(v) => set({ hasBike: v })} />
      {equipment.hasBike && (
        <div className="field" style={{ paddingTop: 10 }}>
          <label>Type de vélo</label>
          <select className="select" value={equipment.bikeType ?? 'road'} onChange={(e) => set({ bikeType: e.target.value as BikeType })}>
            <option value="road">Route</option><option value="tt">Contre-la-montre</option><option value="gravel">Gravel</option><option value="mtb">VTT</option><option value="trainer">Home trainer seul</option>
          </select>
        </div>
      )}
      <Toggle label="Prolongateurs (aéro)" value={equipment.hasAeroBars} onChange={(v) => set({ hasAeroBars: v })} />
      <Toggle label="Capteur de puissance" value={equipment.hasPowerMeter} onChange={(v) => set({ hasPowerMeter: v })} />
      <Toggle label="Home trainer" value={equipment.hasSmartTrainer} onChange={(v) => set({ hasSmartTrainer: v })} />

      <div className="section-title">🏊 Natation</div>
      <Toggle label="Accès piscine" value={equipment.poolAccess} onChange={(v) => set({ poolAccess: v })} />
      <Toggle label="Eau libre" value={equipment.openWaterAccess} onChange={(v) => set({ openWaterAccess: v })} />
      <Toggle label="Combinaison néoprène" value={equipment.hasWetsuit} onChange={(v) => set({ hasWetsuit: v })} />

      <div className="section-title">🏃 Course</div>
      <Toggle label="Course en extérieur" value={equipment.runOutdoor} onChange={(v) => set({ runOutdoor: v })} />
      <Toggle label="Tapis de course" value={equipment.hasTreadmill} onChange={(v) => set({ hasTreadmill: v })} />
      <Toggle label="Accès piste" value={equipment.hasTrack} onChange={(v) => set({ hasTrack: v })} />

      <div className="section-title">💪 Renforcement</div>
      <div className="field" style={{ marginBottom: 0 }}>
        <label>Accès</label>
        <select className="select" value={equipment.strengthAccess} onChange={(e) => set({ strengthAccess: e.target.value as Equipment['strengthAccess'] })}>
          <option value="gym">Salle de sport</option><option value="homeWeights">Matériel à la maison</option><option value="bodyweightOnly">Poids du corps</option><option value="none">Aucun</option>
        </select>
      </div>
    </Card>
  );
}

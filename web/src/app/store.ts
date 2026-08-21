// Store applicatif (Zustand) : AppData persistée + plan dérivé + actions.
// Persistance : LocalProvider (toujours actif) + FirebaseProvider optionnel
// (synchro cloud temps réel, chargé dynamiquement quand configuré).
import { create } from 'zustand';
import {
  PlanBuilder,
  startOfDay,
  type Race,
  type InjuryRecord,
  type CompletedActivity,
  type DailyReadiness,
  type AthleteProfile,
  type Equipment,
  type WeeklyAvailability,
  type ProgressionLevel,
  type TrainingPlan,
  type TemporaryUnavailability,
  type PlannedSession,
  newActivityId,
} from '@engine/index';
import { emptyAppData, demoAppData, type AppData, type AppSettings } from './model';
import { recentWeeklyLoad } from './derive';
import { LocalProvider, exportAppDataFile, importAppDataFile } from '../persistence/syncProvider';
import type { SyncProvider } from '../persistence/syncProvider';
import { isFirebaseConfigured } from '../persistence/firebaseConfig';
import type { CloudUser } from '../persistence/firebaseProvider';

const local = new LocalProvider();
let cloud: SyncProvider | null = null;
let cloudUnsub: (() => void) | null = null;

interface AppStore {
  data: AppData;
  plan: TrainingPlan | null;
  hydrated: boolean;
  cloudUser: CloudUser | null;
  cloudStatus: string | null;
  cloudAvailable: boolean;

  hydrate: () => Promise<void>;
  update: (mutator: (d: AppData) => void, regenerate?: boolean) => void;
  regeneratePlan: () => void;

  loadDemo: () => void;
  reset: () => void;
  completeOnboarding: (partial: Partial<AppData>) => void;

  setProfile: (p: AthleteProfile) => void;
  recalibrate: (r: { vdot?: number; ftpWatts?: number; cssSecPer100m?: number; vma?: number }) => void;
  setEquipment: (e: Equipment) => void;
  setAvailability: (a: WeeklyAvailability) => void;
  setProgression: (p: ProgressionLevel) => void;
  setSettings: (s: Partial<AppSettings>) => void;

  addRace: (r: Race) => void;
  removeRace: (id: string) => void;

  addInjury: (i: InjuryRecord) => void;
  removeInjury: (index: number) => void;

  addUnavailability: (u: TemporaryUnavailability) => void;
  removeUnavailability: (id: string) => void;

  toggleChecklistItem: (raceId: string, key: string) => void;

  markSessionDone: (session: PlannedSession) => void;
  unmarkSessionDone: (session: PlannedSession) => void;
  addActivity: (a: Omit<CompletedActivity, 'id'> & { id?: string }) => void;
  addActivities: (list: Array<Omit<CompletedActivity, 'id'> & { id?: string }>) => void;
  removeActivity: (id: string) => void;
  addReadiness: (r: DailyReadiness) => void;

  exportData: () => void;
  importData: (file: File) => Promise<void>;

  signInCloud: () => Promise<void>;
  signUpEmail: (email: string, password: string) => Promise<void>;
  signInEmail: (email: string, password: string) => Promise<void>;
  resetPassword: (email: string) => Promise<void>;
  signOutCloud: () => Promise<void>;
}

function computePlan(data: AppData): TrainingPlan | null {
  if (!data.profile || data.races.length === 0) return null;
  // Charge de départ réaliste : dérivée de l'entraînement récent (CTL) si dispo.
  const startingWeeklyLoad = recentWeeklyLoad(data) ?? data.settings.startingWeeklyLoad;
  return new PlanBuilder().build(data.profile, data.equipment, data.races, startOfDay(new Date()), data.availability, {
    progression: data.progression,
    poolMeters: data.settings.poolMeters,
    startingWeeklyLoad,
    unavailabilities: data.unavailabilities,
  });
}

export const useStore = create<AppStore>((set, get) => {
  /** Écrit sur le stockage local ET le cloud (si connecté). */
  const saveAll = (data: AppData) => {
    void local.save(data);
    void cloud?.save(data);
  };

  /** Applique des données reçues (chargement, import, push distant). */
  const adopt = (data: AppData) => set({ data, plan: computePlan(data) });

  /**
   * Resynchronise l'agenda après un changement de plan — SEULEMENT si l'utilisateur
   * a déjà connecté Google cette session (sinon on n'ouvre pas de popup). Best-effort.
   */
  const autoSyncCalendar = async () => {
    const { data, plan } = get();
    if (!plan || !data.settings.calendarAutoSync || !data.settings.googleClientId) return;
    try {
      const mod = await import('../services/calendarSync');
      if (!mod.isConnected()) return;
      const today = startOfDay(new Date());
      const upcoming = plan.sessions.filter((s) => s.date >= today);
      const { calendarId } = await mod.syncSessions(upcoming, data.settings.googleCalendarId);
      if (calendarId !== data.settings.googleCalendarId) {
        const d = structuredClone(get().data);
        d.settings.googleCalendarId = calendarId;
        set({ data: d });
        saveAll(d);
      }
    } catch {
      /* synchro silencieuse : en cas d'échec, l'utilisateur peut resync manuellement */
    }
  };

  /** Câble la réconciliation + l'abonnement temps réel après connexion. */
  const wireCloud = async (provider: SyncProvider, user: CloudUser) => {
    cloud = provider;
    const remote = await provider.load();
    if (remote) {
      adopt(remote);
      void local.save(remote);
      set({ cloudStatus: 'Synchronisé depuis le cloud.' });
    } else {
      await provider.save(get().data);
      set({ cloudStatus: 'Données envoyées au cloud.' });
    }
    cloudUnsub?.();
    cloudUnsub = provider.subscribe?.((d) => {
      adopt(d);
      void local.save(d);
    }) ?? null;
    set({ cloudUser: user });
  };

  return {
    data: emptyAppData(),
    plan: null,
    hydrated: false,
    cloudUser: null,
    cloudStatus: null,
    cloudAvailable: isFirebaseConfigured(),

    hydrate: async () => {
      const loaded = await local.load();
      const data = loaded ?? emptyAppData();
      set({ data, plan: computePlan(data), hydrated: true });
      local.subscribe?.((d) => adopt(d));

      // Reconnexion silencieuse au cloud si Firebase est configuré.
      if (isFirebaseConfigured()) {
        try {
          const mod = await import('../persistence/firebaseProvider');
          mod.observeAuth((r) => {
            if (!r) {
              cloudUnsub?.();
              cloudUnsub = null;
              cloud = null;
              set({ cloudUser: null });
              return;
            }
            void wireCloud(r.provider, r.user);
          });
        } catch {
          /* Firebase indisponible : on reste en local. */
        }
      }
    },

    update: (mutator, regenerate = false) => {
      const data = structuredClone(get().data);
      mutator(data);
      set({ data, plan: regenerate ? computePlan(data) : get().plan });
      saveAll(data);
      if (regenerate) void autoSyncCalendar();
    },

    regeneratePlan: () => {
      const data = structuredClone(get().data);
      data.planGeneratedAt = new Date().toISOString();
      set({ data, plan: computePlan(data) });
      saveAll(data);
      void autoSyncCalendar();
    },

    loadDemo: () => {
      const data = demoAppData();
      adopt(data);
      saveAll(data);
    },

    reset: () => {
      const data = emptyAppData();
      set({ data, plan: null });
      saveAll(data);
    },

    completeOnboarding: (partial) =>
      get().update((d) => {
        Object.assign(d, partial);
        d.onboardingComplete = true;
      }, true),

    setProfile: (p) => get().update((d) => { d.profile = p; }, true),
    recalibrate: (r) =>
      get().update((d) => {
        if (!d.profile) return;
        if (r.vma != null) d.profile.vma = r.vma;
        if (r.vdot != null) d.profile.vdot = r.vdot;
        if (r.ftpWatts != null) d.profile.ftpWatts = r.ftpWatts;
        if (r.cssSecPer100m != null) d.profile.cssSecPer100m = r.cssSecPer100m;
      }, true),
    setEquipment: (e) => get().update((d) => { d.equipment = e; }, true),
    setAvailability: (a) => get().update((d) => { d.availability = a; }, true),
    setProgression: (p) => get().update((d) => { d.progression = p; }, true),
    setSettings: (s) => get().update((d) => { d.settings = { ...d.settings, ...s }; }, true),

    addRace: (r) => get().update((d) => { d.races = [...d.races, r]; }, true),
    removeRace: (id) => get().update((d) => { d.races = d.races.filter((r) => r.id !== id); }, true),

    addInjury: (i) => get().update((d) => { d.injuries = [...d.injuries, i]; }, true),
    removeInjury: (index) => get().update((d) => { d.injuries = d.injuries.filter((_, i) => i !== index); }, true),

    addUnavailability: (u) => get().update((d) => { d.unavailabilities = [...d.unavailabilities, u]; }, true),
    removeUnavailability: (id) => get().update((d) => { d.unavailabilities = d.unavailabilities.filter((u) => u.id !== id); }, true),

    toggleChecklistItem: (raceId, key) =>
      get().update((d) => {
        const cur = new Set(d.raceChecklists[raceId] ?? []);
        cur.has(key) ? cur.delete(key) : cur.add(key);
        d.raceChecklists = { ...d.raceChecklists, [raceId]: [...cur] };
      }),

    markSessionDone: (session) =>
      get().update((d) => {
        const id = `done-${session.id}`;
        if (d.activities.some((a) => a.id === id)) return; // déjà marquée → pas de doublon
        d.activities = [
          ...d.activities,
          { id, sport: session.sport, start: session.date, duration: session.estimatedDuration, rpe: 6, source: 'manual' },
        ];
      }),
    unmarkSessionDone: (session) =>
      get().update((d) => {
        d.activities = d.activities.filter((a) => a.id !== `done-${session.id}`);
      }),
    addActivity: (a) => get().update((d) => { d.activities = [...d.activities, { ...a, id: a.id ?? newActivityId() }]; }),
    addActivities: (list) =>
      get().update((d) => {
        d.activities = [...d.activities, ...list.map((a) => ({ ...a, id: a.id ?? newActivityId() }))];
      }),
    removeActivity: (id) => get().update((d) => { d.activities = d.activities.filter((a) => a.id !== id); }),
    addReadiness: (r) =>
      get().update((d) => {
        const others = d.readiness.filter((x) => startOfDay(x.date).getTime() !== startOfDay(r.date).getTime());
        d.readiness = [...others, r].sort((x, y) => x.date.getTime() - y.date.getTime());
      }),

    exportData: () => exportAppDataFile(get().data),
    importData: async (file) => {
      const data = await importAppDataFile(file);
      adopt(data);
      saveAll(data);
    },

    signInCloud: async () => {
      if (!isFirebaseConfigured()) {
        set({ cloudStatus: 'Firebase non configuré (voir README : variables VITE_FIREBASE_*).' });
        return;
      }
      set({ cloudStatus: 'Connexion à Google…' });
      try {
        const mod = await import('../persistence/firebaseProvider');
        await mod.signInWithGoogle(); // le handler observeAuth câble la synchro
      } catch (e) {
        set({ cloudStatus: `Échec : ${(e as Error).message}` });
      }
    },

    signUpEmail: async (email, password) => {
      set({ cloudStatus: 'Création du compte…' });
      const mod = await import('../persistence/firebaseProvider');
      await mod.signUpEmail(email, password); // le handler observeAuth branche la synchro
    },

    signInEmail: async (email, password) => {
      set({ cloudStatus: 'Connexion…' });
      const mod = await import('../persistence/firebaseProvider');
      await mod.signInEmail(email, password);
    },

    resetPassword: async (email) => {
      const mod = await import('../persistence/firebaseProvider');
      await mod.resetPassword(email);
    },

    signOutCloud: async () => {
      try {
        const mod = await import('../persistence/firebaseProvider');
        await mod.signOutFirebase();
      } catch {
        /* ignore */
      }
      cloudUnsub?.();
      cloudUnsub = null;
      cloud = null;
      set({ cloudUser: null, cloudStatus: 'Déconnecté du cloud (données locales conservées).' });
    },
  };
});

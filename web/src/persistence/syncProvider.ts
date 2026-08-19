// Abstraction de persistance multi-appareils. Trois implémentations prévues :
//  - LocalProvider  : localStorage (toujours actif, zéro config) + export/import JSON.
//  - FirebaseProvider: Auth Google + Firestore (recommandé, temps réel) — à brancher.
//  - DriveProvider   : Google Drive appDataFolder (réutilise l'OAuth Agenda) — à brancher.
import type { AppData } from '../app/model';
import { deserializeAppData, serializeAppData } from '../app/serialization';

export interface SyncProvider {
  readonly id: string;
  readonly displayName: string;
  load(): Promise<AppData | null>;
  save(data: AppData): Promise<void>;
  /** Notifié quand une autre source (autre appareil) modifie les données. */
  subscribe?(onChange: (data: AppData) => void): () => void;
}

const STORAGE_KEY = 'coachtri.appdata.v1';

export class LocalProvider implements SyncProvider {
  readonly id = 'local';
  readonly displayName = 'Cet appareil (local)';

  async load(): Promise<AppData | null> {
    try {
      const raw = localStorage.getItem(STORAGE_KEY);
      return raw ? deserializeAppData(raw) : null;
    } catch {
      return null;
    }
  }

  async save(data: AppData): Promise<void> {
    localStorage.setItem(STORAGE_KEY, serializeAppData(data));
  }

  /** Synchronise entre onglets du même appareil (event `storage`). */
  subscribe(onChange: (data: AppData) => void): () => void {
    const handler = (e: StorageEvent) => {
      if (e.key === STORAGE_KEY && e.newValue) {
        try {
          onChange(deserializeAppData(e.newValue));
        } catch {
          /* ignore */
        }
      }
    };
    window.addEventListener('storage', handler);
    return () => window.removeEventListener('storage', handler);
  }
}

// Export / import JSON (dépannage, sauvegarde, migration d'appareil).

export function exportAppDataFile(data: AppData): void {
  const blob = new Blob([serializeAppData(data)], { type: 'application/json' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = `coach-triathlon-${new Date().toISOString().slice(0, 10)}.json`;
  a.click();
  URL.revokeObjectURL(url);
}

export async function importAppDataFile(file: File): Promise<AppData> {
  const text = await file.text();
  return deserializeAppData(text);
}

// Capture l'événement d'installation PWA (Chrome/Edge/Android) pour proposer
// un bouton « Installer l'app ». iOS Safari n'émet pas cet événement → sur iOS,
// l'installation se fait via Partager → « Sur l'écran d'accueil ».

interface BeforeInstallPromptEvent extends Event {
  prompt: () => Promise<void>;
  userChoice: Promise<{ outcome: 'accepted' | 'dismissed' }>;
}

let deferred: BeforeInstallPromptEvent | null = null;

export function initInstallPrompt(): void {
  window.addEventListener('beforeinstallprompt', (e) => {
    e.preventDefault();
    deferred = e as BeforeInstallPromptEvent;
    window.dispatchEvent(new Event('pwa-installable'));
  });
  window.addEventListener('appinstalled', () => {
    deferred = null;
    window.dispatchEvent(new Event('pwa-installed'));
  });
}

export function canInstall(): boolean {
  return deferred != null;
}

export async function promptInstall(): Promise<boolean> {
  if (!deferred) return false;
  await deferred.prompt();
  const choice = await deferred.userChoice;
  deferred = null;
  window.dispatchEvent(new Event('pwa-installed'));
  return choice.outcome === 'accepted';
}

/** L'app tourne-t-elle déjà en mode installé (standalone) ? */
export function isStandalone(): boolean {
  return window.matchMedia('(display-mode: standalone)').matches || (navigator as unknown as { standalone?: boolean }).standalone === true;
}

// Checklist matériel du jour de course, adaptée au format et au matériel.
import { isTriathlon, type Equipment, type RaceFormat } from '@engine/index';

export interface ChecklistSection {
  title: string;
  items: string[];
}

export function raceChecklist(format: RaceFormat, equipment: Equipment): ChecklistSection[] {
  const tri = isTriathlon(format);
  const sections: ChecklistSection[] = [];

  if (tri) {
    const swim: string[] = ['Bonnet (souvent fourni)', 'Lunettes de natation (+ paire de secours)', 'Trifonction / combinaison de tri'];
    if (equipment.hasWetsuit) swim.push('Combinaison néoprène (si autorisée)');
    swim.push('Crème anti-frottement (cou/aisselles)');
    sections.push({ title: '🏊 Natation', items: swim });

    sections.push({
      title: '🚴 Vélo',
      items: [
        'Vélo vérifié (freins, pneus, transmission)',
        'Casque OBLIGATOIRE (à clipper avant de toucher le vélo)',
        'Chaussures vélo',
        'Bidons remplis (boisson énergétique)',
        'Kit anti-crevaison + gonfleur/CO₂',
        'Compteur / capteur chargé',
      ],
    });

    sections.push({
      title: '🔄 Transition',
      items: ['Serviette repère au sol', 'Dossard sur ceinture porte-dossard', 'Élastiques / talc pour enfiler vite', 'Ravitaillement posé et accessible'],
    });
  }

  const run: string[] = ['Chaussures de course', 'Tenue adaptée à la météo'];
  if (!tri) run.push('Dossard épinglé (4 épingles)', 'Ceinture porte-dossard (option)');
  run.push('Casquette / visière si chaleur');
  sections.push({ title: '🏃 Course', items: run });

  sections.push({
    title: '🍫 Ravitaillement',
    items: ['Gels / barres (voir plan nutrition)', 'Boisson énergétique', 'Pastilles de sel si chaleur/long'],
  });

  sections.push({
    title: '📋 Divers',
    items: ['Puce de chronométrage', 'Licence / certificat / pièce d\'identité', 'Montre GPS chargée', 'Crème solaire', 'Vêtement chaud pour après', 'Épingles à nourrice'],
  });

  return sections;
}

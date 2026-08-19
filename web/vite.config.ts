import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import { VitePWA } from 'vite-plugin-pwa';
import path from 'node:path';

// `base` doit correspondre au nom du repo GitHub Pages (https://<user>.github.io/<repo>/).
// Surchargé par la variable d'env BASE_PATH en CI ; « / » en dev.
const base = process.env.BASE_PATH ?? '/';

export default defineConfig({
  base,
  resolve: {
    alias: {
      '@engine': path.resolve(__dirname, 'src/engine'),
      '@': path.resolve(__dirname, 'src'),
    },
  },
  plugins: [
    react(),
    VitePWA({
      registerType: 'autoUpdate',
      includeAssets: ['favicon.svg', 'apple-touch-icon.png'],
      manifest: {
        name: 'Coach Triathlon IA',
        short_name: 'CoachTri',
        lang: 'fr',
        description: 'Coach triathlon IA : plan adaptatif, journal, prédictions.',
        theme_color: '#0A0E13',
        background_color: '#0A0E13',
        display: 'standalone',
        icons: [
          { src: 'pwa-192.png', sizes: '192x192', type: 'image/png' },
          { src: 'pwa-512.png', sizes: '512x512', type: 'image/png' },
          { src: 'pwa-512.png', sizes: '512x512', type: 'image/png', purpose: 'maskable' },
          { src: 'favicon.svg', sizes: 'any', type: 'image/svg+xml' },
        ],
      },
    }),
  ],
});

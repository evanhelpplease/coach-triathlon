import React from 'react';
import ReactDOM from 'react-dom/client';
import { registerSW } from 'virtual:pwa-register';
import './styles/tokens.css';
import './ui/components.css';
import './ui/layout.css';
import { App } from './App';
import { initInstallPrompt } from './pwa/install';

registerSW({ immediate: true });
initInstallPrompt();

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>,
);

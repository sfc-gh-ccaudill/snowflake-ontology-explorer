import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

// The React dev server proxies /api to the Express backend so the browser
// only ever talks to one origin (no CORS headaches in the browser).
export default defineConfig({
  plugins: [react()],
  server: {
    port: 5173,
    proxy: {
      '/api': {
        target: 'http://localhost:3001',
        changeOrigin: true,
      },
    },
  },
});

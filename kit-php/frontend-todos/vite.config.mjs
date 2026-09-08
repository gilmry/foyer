import { defineConfig } from 'vite';
import { svelte } from '@sveltejs/vite-plugin-svelte';
import { resolve } from 'node:path';

// Build de l'îlot en IIFE auto-montant → public/todos-island/index.js
export default defineConfig({
  plugins: [svelte()],
  build: {
    outDir: resolve(import.meta.dirname, '../public/todos-island'),
    emptyOutDir: true,
    lib: {
      entry: resolve(import.meta.dirname, 'src/mount.js'),
      formats: ['iife'],
      name: 'TodosIsland',
      fileName: () => 'index.js',
    },
  },
});

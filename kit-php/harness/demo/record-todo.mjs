// record-todo.mjs — enregistre la vidéo de la story « parcours de référence » du todo :
// créer → basculer → supprimer une tâche, narré et cadencé. La vidéo est la PREUVE DE VALEUR
// (documentation vivante), rejouée depuis le MÊME parcours que l'E2E — pas de doc dédoublée.
import { chromium } from 'playwright';
import { Scene } from './scene.mjs';
import { mkdirSync, existsSync, readdirSync, renameSync, writeFileSync } from 'node:fs';
import { resolve, dirname } from 'node:path';

const BASE = process.env.DEMO_BASE_URL ?? 'http://127.0.0.1:8080';
const HERE = dirname(new URL(import.meta.url).pathname);
const VIDEO_DIR = resolve(HERE, 'vitrine/videos');
const SLUG = 'todo-parcours-de-reference';

if (!existsSync(VIDEO_DIR)) mkdirSync(VIDEO_DIR, { recursive: true });

const browser = await chromium.launch({ args: ['--no-sandbox', '--disable-dev-shm-usage'] });
const context = await browser.newContext({
  viewport: { width: 1280, height: 720 },
  recordVideo: { dir: VIDEO_DIR, size: { width: 1280, height: 720 } },
});
const page = await context.newPage();
const scene = new Scene(page);

await scene.aller(`${BASE}/`);
await scene.raconter('Todo — application de test. Preuve de valeur : le parcours de référence, rejoué en cadence.');

await scene.raconter('1) Ajouter une tâche : « acheter du pain ».');
await scene.saisir('#todoSection input[type=text]', 'acheter du pain');
await scene.cliquer('#todoSection button[type=submit]');

await scene.raconter('2) Ajouter une deuxième tâche : « réviser Foyer ».');
await scene.saisir('#todoSection input[type=text]', 'réviser Foyer');
await scene.cliquer('#todoSection button[type=submit]');

await scene.raconter('3) Marquer « acheter du pain » comme faite (elle se barre).');
await scene.cocher('#todoSection li:first-child input[type=checkbox]');

await scene.raconter('4) Supprimer la tâche faite.');
await scene.cliquer('#todoSection li:first-child button.delete');

await scene.raconter('La liste est persistée en base : elle survit au rechargement.');
await scene.aller(`${BASE}/`);
await scene.raconter('Parcours terminé — même parcours que l\'E2E (correctness) et le golden (apparence).');

await context.close(); // flush de la vidéo
await browser.close();

// Renomme la vidéo générée (nom aléatoire Playwright) en un slug stable.
const files = readdirSync(VIDEO_DIR).filter((f) => f.endsWith('.webm'));
const latest = files.map((f) => resolve(VIDEO_DIR, f)).sort()[files.length - 1];
const finalPath = resolve(VIDEO_DIR, `${SLUG}.webm`);
if (latest && latest !== finalPath) renameSync(latest, finalPath);

// Journal de narration (sert de sous-titres / chapitres dans la vitrine).
writeFileSync(
  resolve(VIDEO_DIR, `${SLUG}.json`),
  JSON.stringify({ slug: SLUG, title: 'Parcours de référence — créer, terminer, supprimer', narration: scene.narration }, null, 2),
);

console.log(`  🎬 vidéo : ${finalPath} (${scene.narration.length} étapes narrées)`);

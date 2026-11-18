// record-todo.mjs — enregistre la vidéo de la story « parcours de référence » du todo :
// créer un compte → se connecter → créer → basculer → supprimer une tâche → se déconnecter, narré et cadencé. La vidéo est la PREUVE DE VALEUR
// (documentation vivante), rejouée depuis le MÊME parcours que l'E2E — pas de doc dédoublée.
import { chromium } from 'playwright';
import { Scene } from './scene.mjs';
import { mkdirSync, existsSync, readdirSync, renameSync, statSync, writeFileSync } from 'node:fs';
import { resolve, dirname } from 'node:path';

const BASE = process.env.DEMO_BASE_URL ?? 'http://127.0.0.1:8080';
const EMAIL = process.env.DEMO_EMAIL ?? 'demo@exemple.test';
const PASSWORD = process.env.DEMO_PASSWORD ?? '';
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

await scene.raconter('Sans compte, rien n\'est visible : l\'API répond 401 et l\'îlot demande de se connecter.');
await scene.cliquer('#todoSection form.auth button.link');
await scene.raconter('0) Créer un compte, puis la session s\'ouvre (cookie HttpOnly, SameSite=Strict).');
await scene.saisir('#todoSection form.auth input[type=email]', EMAIL);
await scene.saisir('#todoSection form.auth input[type=password]', PASSWORD);
await scene.cliquer('#todoSection form.auth button[type=submit]');
await page.waitForSelector('#todoSection form.create', { timeout: 15000 });

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

await scene.raconter('La liste est persistée en base : elle survit au rechargement, et n\'appartient qu\'à ce compte.');
await scene.aller(`${BASE}/`);
await scene.raconter('5) Se déconnecter : l\'API se referme.');
await scene.cliquer('#todoSection button.logout');
await scene.raconter('Parcours terminé — même parcours que l\'E2E (correctness) et le golden (apparence).');

await context.close(); // flush de la vidéo
await browser.close();

// Renomme la vidéo générée (nom aléatoire Playwright) en un slug stable. La plus récente des
// vidéos au nom aléatoire remplace l'ancienne vidéo du slug.
const finalPath = resolve(VIDEO_DIR, `${SLUG}.webm`);
const latest = readdirSync(VIDEO_DIR)
  .filter((f) => f.endsWith('.webm') && f !== `${SLUG}.webm`)
  .map((f) => resolve(VIDEO_DIR, f))
  .sort((a, b) => statSync(a).mtimeMs - statSync(b).mtimeMs)
  .pop();
if (latest) renameSync(latest, finalPath);

// Journal de narration (sert de sous-titres / chapitres dans la vitrine).
writeFileSync(
  resolve(VIDEO_DIR, `${SLUG}.json`),
  JSON.stringify({ slug: SLUG, title: 'Parcours de référence — se connecter, créer, terminer, supprimer', narration: scene.narration }, null, 2),
);

console.log(`  🎬 vidéo : ${finalPath} (${scene.narration.length} étapes narrées)`);

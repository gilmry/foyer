// record-todo.mjs — enregistre la vidéo de la story « parcours de référence » du todo :
// créer un compte → créer → basculer → supprimer une tâche → se déconnecter, narré et cadencé. La vidéo est la PREUVE DE VALEUR
// (documentation vivante), rejouée depuis le MÊME parcours que l'E2E — pas de doc dédoublée.
import { chromium } from 'playwright';
import { Scene } from './scene.mjs';
import { mkdirSync, existsSync, readdirSync, renameSync, writeFileSync } from 'node:fs';
import { resolve, dirname } from 'node:path';
import { randomBytes } from 'node:crypto';

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

// Compte de la démonstration : courriel fixe, mot de passe tiré à chaque enregistrement (le champ
// le masque à l'écran). serve.sh ouvre l'inscription pour ce harnais.
const EMAIL = 'demo@exemple.test';
const PASSWORD = randomBytes(18).toString('hex');

await scene.aller(`${BASE}/`);
await scene.raconter('Todo — application de test. Preuve de valeur : le parcours de référence, rejoué en cadence.');

await scene.raconter('Sans session, l\'API refuse (401) : l\'application propose de se connecter. Créons un compte.');
await scene.cliquer('#todoSection button.switch');
await scene.saisir('#todoSection input[type=email]', EMAIL);
await scene.saisir('#todoSection input[type=password]', PASSWORD);
await scene.cliquer('#todoSection form.auth button[type=submit]');
await scene.raconter('Compte créé, session ouverte : chacun ne voit que ses propres tâches.');

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

await scene.raconter('La liste est persistée en base, et la session tient : tout survit au rechargement.');
await scene.aller(`${BASE}/`);
await scene.raconter('Se déconnecter révoque la session côté serveur : retour au formulaire.');
await scene.cliquer('#todoSection button.logout');
await scene.raconter('Parcours terminé — même parcours que l\'E2E (correctness) et le golden (apparence).');

await context.close(); // flush de la vidéo
await browser.close();

// Renomme la vidéo générée (nom aléatoire Playwright) en un slug stable.
// La vidéo fraîche porte un nom aléatoire : on écarte l'ancienne, déjà renommée.
const files = readdirSync(VIDEO_DIR).filter((f) => f.endsWith('.webm') && f !== `${SLUG}.webm`);
const latest = files.map((f) => resolve(VIDEO_DIR, f)).sort()[files.length - 1];
const finalPath = resolve(VIDEO_DIR, `${SLUG}.webm`);
if (latest && latest !== finalPath) renameSync(latest, finalPath);

// Journal de narration (sert de sous-titres / chapitres dans la vitrine).
writeFileSync(
  resolve(VIDEO_DIR, `${SLUG}.json`),
  JSON.stringify({ slug: SLUG, title: 'Parcours de référence — créer, terminer, supprimer', narration: scene.narration }, null, 2),
);

console.log(`  🎬 vidéo : ${finalPath} (${scene.narration.length} étapes narrées)`);

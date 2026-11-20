// Harnais de preuve visuelle du périmètre Todo.
// Rejoue le parcours de référence dans un vrai Chromium : formulaire de connexion (l'API répond
// 401), connexion PAR L'UI, puis la liste. Capture #todoSection, et selon le mode : écrit le golden (capture) ou compare au golden (compare, gate `visuel`).
//
//   VISUAL_MODE=capture  → (ré)écrit les goldens (à faire quand le rendu change intentionnellement)
//   VISUAL_MODE=compare  → compare la capture au golden, échoue si diff > tolérance (défaut)
//
// L'îlot n'a pas d'URL en dur : il consomme le client généré. Le parcours est le MÊME que l'E2E.
import { chromium } from 'playwright';
import { PNG } from 'pngjs';
import pixelmatch from 'pixelmatch';
import { readFileSync, writeFileSync, existsSync, mkdirSync } from 'node:fs';
import { dirname, resolve } from 'node:path';

const BASE = process.env.VISUAL_BASE_URL ?? 'http://127.0.0.1:8080';
const MODE = process.env.VISUAL_MODE ?? 'compare';
const TOLERANCE = Number(process.env.VISUAL_TOLERANCE ?? '0.005'); // 0,5 % de pixels
const HERE = dirname(new URL(import.meta.url).pathname);
const GOLDEN_DIR = resolve(HERE, 'goldens');
const OUT_DIR = resolve(HERE, 'test-results');

const EMAIL = process.env.VISUAL_EMAIL ?? '';
const PASSWORD = process.env.VISUAL_PASSWORD ?? '';

const CASES = [
  { name: 'todo-page', scope: null, file: 'todo-page.png' }, // page entière
  { name: 'todo-island', scope: '#todoSection', file: 'todo-island.png' }, // l'îlot seul
];
const LOGIN_CASE = { name: 'todo-login', scope: '#todoSection', file: 'todo-login.png' }; // formulaire de connexion

function ensureDir(p) {
  if (!existsSync(p)) mkdirSync(p, { recursive: true });
}

async function run() {
  ensureDir(GOLDEN_DIR);
  ensureDir(OUT_DIR);

  const browser = await chromium.launch({
    args: ['--no-sandbox', '--disable-dev-shm-usage'],
  });
  const page = await browser.newPage({
    viewport: { width: 1280, height: 900 },
    reducedMotion: 'reduce',
  });

  if (process.env.VISUAL_SCENARIO === 'jeton') {
    await jeton(page);
    await browser.close();
    return;
  }

  let failures = 0;

  // 1. Ouvrir la page sans session : l'API répond 401, l'îlot montre le formulaire de connexion.
  await page.goto(`${BASE}/`, { waitUntil: 'networkidle' });
  await page.waitForSelector('#todoSection form.auth input[type=email]', { timeout: 15_000 });
  failures += await check(page, LOGIN_CASE);
  // 2. Se connecter par l'UI (interaction réelle : cookie de session, en-tête Origin du navigateur).
  await page.fill('#todoSection form.auth input[type=email]', EMAIL);
  await page.fill('#todoSection form.auth input[type=password]', PASSWORD);
  await page.click('#todoSection form.auth button[type=submit]');
  // 3. Attendre que le parcours ait peuplé la liste (au moins une tâche seedée).
  await page.waitForSelector('#todoSection li', { state: 'attached', timeout: 15_000 });
  // 4. Basculer la première tâche via l'UI (interaction réelle, pas l'API).
  await page.locator('#todoSection li input[type=checkbox]').first().check();
  await page.waitForTimeout(300); // laisse le re-render se stabiliser
  // 5. Retirer le focus (l'anneau de focus bleu est une source de bruit inter-runs).
  await page.evaluate(() => document.activeElement instanceof HTMLElement && document.activeElement.blur());
  await page.waitForTimeout(100);

  for (const c of CASES) failures += await check(page, c);

  // 6. Se déconnecter par l'UI : retour au formulaire, et l'API refuse de nouveau.
  await page.click('#todoSection button.logout');
  await page.waitForSelector('#todoSection form.auth', { timeout: 15_000 });
  const apres = await page.evaluate(() => fetch('api/todos').then((r) => r.status));
  if (apres !== 401) {
    console.error(`  ✗ déconnexion : GET api/todos attendu 401, obtenu ${apres}`);
    failures++;
  } else {
    console.log('  ✓ déconnexion : formulaire de retour, API refusée (401)');
  }

  await browser.close();
  console.log('');
  console.log(`visuel: ${failures === 0 ? '🟢' : '🔴'} (mode ${MODE})`);
  process.exit(failures === 0 ? 0 : 1);
}

/**
 * Adaptateur vanilla : pas de session. L'îlot montre un champ de jeton ; on y colle un jeton
 * porteur, la liste apparaît, on bascule une tâche, puis « Se déconnecter » oublie le jeton.
 * Parcours fonctionnel, sans golden.
 */
async function jeton(page) {
  await page.goto(`${BASE}/`, { waitUntil: 'networkidle' });
  await page.waitForSelector('#todoSection form.auth input[type=password]', { timeout: 15_000 });
  const champs = await page.locator('#todoSection form.auth input').count();
  await page.fill('#todoSection form.auth input[type=password]', process.env.VISUAL_TOKEN ?? '');
  await page.click('#todoSection form.auth button[type=submit]');
  await page.waitForSelector('#todoSection li', { state: 'attached', timeout: 15_000 });
  const avant = await page.locator('#todoSection li.done').count();
  await page.locator('#todoSection li:not(.done) input[type=checkbox]').first().check();
  // (Pas de waitForFunction : la politique de sécurité du contenu de la page interdit eval.)
  await page.locator('#todoSection li.done').nth(avant).waitFor({ state: 'attached', timeout: 15_000 });
  await page.click('#todoSection button.logout');
  await page.waitForSelector('#todoSection form.auth', { timeout: 15_000 });
  const ok = champs === 1;
  console.log(`  ${ok ? '✓' : '✗'} adaptateur vanilla : champ de jeton seul (${champs} champ), liste affichée, tâche basculée, jeton oublié`);
  console.log('');
  console.log(`visuel (îlot sur l'adaptateur vanilla, jeton porteur): ${ok ? '🟢' : '🔴'}`);
  process.exit(ok ? 0 : 1);
}

/** Capture un cas et l'écrit (capture) ou le compare au golden. Rend le nombre d'échecs (0 ou 1). */
async function check(page, c) {
  await page.evaluate(() => document.activeElement instanceof HTMLElement && document.activeElement.blur());
  let failures = 0;
  {
    const target = c.scope ? page.locator(c.scope) : page;
    const shotPath = resolve(OUT_DIR, c.file);
    await target.screenshot({ path: shotPath, animations: 'disabled', caret: 'hide' });
    const shot = PNG.sync.read(readFileSync(shotPath));

    const goldenPath = resolve(GOLDEN_DIR, c.file);
    if (MODE === 'capture' || !existsSync(goldenPath)) {
      writeFileSync(goldenPath, PNG.sync.write(shot));
      console.log(`  ⬇ golden écrit : ${c.file} (${shot.width}×${shot.height})`);
      return 0;
    }

    const golden = PNG.sync.read(readFileSync(goldenPath));
    if (golden.width !== shot.width || golden.height !== shot.height) {
      console.error(`  ✗ ${c.name} : dimensions différentes (golden ${golden.width}×${golden.height} vs ${shot.width}×${shot.height})`);
      return 1;
    }
    const diff = new PNG({ width: shot.width, height: shot.height });
    const changed = pixelmatch(golden.data, shot.data, diff.data, shot.width, shot.height, { threshold: 0.1 });
    const ratio = changed / (shot.width * shot.height);
    if (ratio > TOLERANCE) {
      writeFileSync(resolve(OUT_DIR, `${c.name}.diff.png`), PNG.sync.write(diff));
      console.error(`  ✗ ${c.name} : ${(ratio * 100).toFixed(3)} % de pixels changés (> ${(TOLERANCE * 100).toFixed(1)} %)`);
      failures++;
    } else {
      console.log(`  ✓ ${c.name} : ${(ratio * 100).toFixed(3)} % (≤ ${(TOLERANCE * 100).toFixed(1)} %)`);
    }
  }
  return failures;
}

run().catch((e) => {
  console.error(e);
  process.exit(1);
});

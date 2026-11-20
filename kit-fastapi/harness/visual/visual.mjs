// Harnais de preuve visuelle du périmètre Todo.
// Rejoue le parcours de référence dans un vrai Chromium : formulaire de connexion (l'API répond
// 401 sans session), connexion par le formulaire, puis la liste. Capture #todoSection,
// et selon le mode : écrit le golden (capture) ou compare au golden (compare, gate `visuel`).
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

const EMAIL = process.env.VISUAL_EMAIL;
const PASSWORD = process.env.VISUAL_PASSWORD;

// Écran de connexion, capturé AVANT de se connecter.
const LOGIN_CASES = [
  { name: 'todo-connexion', scope: '#todoSection', file: 'todo-connexion.png' },
];
// Liste, capturée une fois connecté.
const CASES = [
  { name: 'todo-page', scope: null, file: 'todo-page.png' }, // page entière
  { name: 'todo-island', scope: '#todoSection', file: 'todo-island.png' }, // l'îlot seul
];

function ensureDir(p) {
  if (!existsSync(p)) mkdirSync(p, { recursive: true });
}

async function defocus(page) {
  // Retirer le focus (l'anneau de focus bleu est une source de bruit inter-runs).
  await page.evaluate(() => document.activeElement instanceof HTMLElement && document.activeElement.blur());
  await page.waitForTimeout(100);
}

/** Capture chaque cas et l'écrit (capture) ou le compare au golden ; rend le nombre d'échecs. */
async function check(page, cases) {
  let failures = 0;
  for (const c of cases) {
    const target = c.scope ? page.locator(c.scope) : page;
    const shotPath = resolve(OUT_DIR, c.file);
    await target.screenshot({ path: shotPath, animations: 'disabled', caret: 'hide' });
    const shot = PNG.sync.read(readFileSync(shotPath));

    const goldenPath = resolve(GOLDEN_DIR, c.file);
    if (MODE === 'capture' || !existsSync(goldenPath)) {
      writeFileSync(goldenPath, PNG.sync.write(shot));
      console.log(`  ⬇ golden écrit : ${c.file} (${shot.width}×${shot.height})`);
      continue;
    }

    const golden = PNG.sync.read(readFileSync(goldenPath));
    if (golden.width !== shot.width || golden.height !== shot.height) {
      console.error(`  ✗ ${c.name} : dimensions différentes (golden ${golden.width}×${golden.height} vs ${shot.width}×${shot.height})`);
      failures++;
      continue;
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

async function run() {
  if (!EMAIL || !PASSWORD) throw new Error('VISUAL_EMAIL et VISUAL_PASSWORD sont requis (voir harness/run-visual.sh)');
  ensureDir(GOLDEN_DIR);
  ensureDir(OUT_DIR);

  const browser = await chromium.launch({
    args: ['--no-sandbox', '--disable-dev-shm-usage'],
  });
  const page = await browser.newPage({
    viewport: { width: 1280, height: 900 },
    reducedMotion: 'reduce',
  });
  // Une violation de la politique de sécurité du contenu (CSP) casserait l'îlot sans bruit : on l'écoute.
  const cspViolations = [];
  page.on('console', (m) => {
    if (m.type() === 'error' && /Content Security Policy/i.test(m.text())) cspViolations.push(m.text());
  });

  // 1. Ouvrir la page : sans session, l'API répond 401 et l'îlot montre le formulaire de connexion.
  await page.goto(`${BASE}/`, { waitUntil: 'networkidle' });
  await page.waitForSelector('#todoSection form.auth', { state: 'attached', timeout: 15_000 });
  await defocus(page);
  let failures = await check(page, LOGIN_CASES);

  // 2. Se connecter par le formulaire (interaction réelle : le cookie de session est posé par l'API).
  await page.locator('#todoSection input[type=email]').fill(EMAIL);
  await page.locator('#todoSection input[type=password]').fill(PASSWORD);
  await page.locator('#todoSection form.auth button[type=submit]').click();
  // 3. Attendre que la liste seedée soit là : l'îlot l'a chargée via le client généré.
  await page.waitForSelector('#todoSection li', { state: 'attached', timeout: 15_000 });
  // 4. Basculer la première tâche via l'UI (interaction réelle, pas l'API).
  await page.locator('#todoSection li input[type=checkbox]').first().check();
  await page.waitForTimeout(300); // laisse le re-render se stabiliser
  await defocus(page);
  failures += await check(page, CASES);

  if (cspViolations.length) {
    console.error(`  ✗ ${cspViolations.length} violation(s) de la politique de sécurité du contenu : ${cspViolations[0]}`);
    failures++;
  } else {
    console.log('  ✓ aucune violation de la politique de sécurité du contenu');
  }

  await browser.close();
  console.log('');
  console.log(`visuel: ${failures === 0 ? '🟢' : '🔴'} (mode ${MODE})`);
  process.exit(failures === 0 ? 0 : 1);
}

run().catch((e) => {
  console.error(e);
  process.exit(1);
});

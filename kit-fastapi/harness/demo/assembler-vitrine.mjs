// assembler-vitrine.mjs — agrège les vidéos + narrations en une galerie HTML (la « vitrine »),
// preuve de valeur consultable. Statique, autonome (aucune dépendance réseau).
import { readdirSync, readFileSync, writeFileSync } from 'node:fs';
import { resolve, dirname } from 'node:path';

const HERE = dirname(new URL(import.meta.url).pathname);
const VIDEO_DIR = resolve(HERE, 'vitrine/videos');
const OUT = resolve(HERE, 'vitrine/index.html');

const metas = readdirSync(VIDEO_DIR)
  .filter((f) => f.endsWith('.json'))
  .map((f) => JSON.parse(readFileSync(resolve(VIDEO_DIR, f), 'utf8')));

const cards = metas
  .map((m) => {
    const chapitres = (m.narration ?? [])
      .map((n) => `<li><span class="t">${String(n.t).padStart(2, '0')}s</span> ${escapeHtml(n.texte)}</li>`)
      .join('');
    return `
      <article class="carte">
        <h2>${escapeHtml(m.title)}</h2>
        <video controls preload="metadata" src="videos/${m.slug}.webm"></video>
        <ol class="chapitres">${chapitres}</ol>
      </article>`;
  })
  .join('');

const html = `<!DOCTYPE html>
<html lang="fr">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>Vitrine — Todo (preuve de valeur)</title>
  <style>
    body { font: 16px/1.5 system-ui, sans-serif; margin: 0; background: #f6f7f9; color: #111827; }
    header { background: #111827; color: #fff; padding: 24px; }
    header h1 { margin: 0 0 4px; font-size: 22px; }
    header p { margin: 0; opacity: .8; font-size: 14px; }
    main { max-width: 920px; margin: 24px auto; padding: 0 16px; display: grid; gap: 24px; }
    .carte { background: #fff; border-radius: 12px; box-shadow: 0 1px 4px rgba(0,0,0,.08); padding: 16px; }
    .carte h2 { margin: 0 0 12px; font-size: 18px; }
    video { width: 100%; border-radius: 8px; background: #000; }
    .chapitres { margin: 12px 0 0; padding-left: 0; list-style: none; font-size: 14px; color: #374151; }
    .chapitres li { padding: 2px 0; }
    .chapitres .t { display: inline-block; width: 3em; color: #6b7280; font-variant-numeric: tabular-nums; }
    footer { text-align: center; color: #6b7280; font-size: 13px; padding: 24px; }
  </style>
</head>
<body>
  <header>
    <h1>Vitrine — Todo (application de test)</h1>
    <p>Preuve de valeur — parcours de référence rejoué en cadence. Même parcours que l'E2E (correctness) et le golden visuel (apparence).</p>
  </header>
  <main>${cards || '<p>Aucune vidéo. Lancer <code>bash harness/run-demo.sh</code>.</p>'}</main>
  <footer>Documentation vivante générée par harness/demo — cadre Foyer.</footer>
</body>
</html>`;

writeFileSync(OUT, html);
console.log(`  🖼  vitrine : ${OUT} (${metas.length} vidéo(s))`);

function escapeHtml(s) {
  return String(s).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
}

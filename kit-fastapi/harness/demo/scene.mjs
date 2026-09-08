// scene.mjs — cœur de la documentation vidéo vivante (transposé du pattern « klaar »
// du kit stagesmed). Pilote une page Playwright en cadence (~1 action/s) avec une
// narration incrustée dans le DOM (visible dans la vidéo). Pas d'auth ici (todo mono-utilisateur).

export const RHYTHM_MS = Number(process.env.DEMO_RHYTHM_MS ?? 1000);

/** Pilote UNE page avec narration + tempo. */
export class Scene {
  constructor(page) {
    this.page = page;
    this.narration = [];
    this._t0 = null;
  }

  async _tempo() {
    await this.page.waitForTimeout(RHYTHM_MS);
  }

  /** Bandeau de narration incrusté (décoratif, n'intercepte pas les clics). */
  async raconter(texte) {
    if (this._t0 === null) this._t0 = Date.now();
    this.narration.push({ t: Math.round((Date.now() - this._t0) / 1000), texte });
    const ms = Math.min(5000, Math.max(1400, texte.length * 70));
    await this.page
      .evaluate(
        ({ texte, ms }) => {
          const id = 'demo-narration';
          let el = document.getElementById(id);
          if (!el) {
            el = document.createElement('div');
            el.id = id;
            el.style.cssText =
              'position:fixed;left:20px;right:20px;bottom:20px;z-index:2147483647;pointer-events:none;' +
              'background:rgba(17,24,39,.92);color:#fff;padding:14px 18px;border-radius:10px;' +
              'font:500 16px/1.4 system-ui,sans-serif;box-shadow:0 8px 30px rgba(0,0,0,.35);' +
              'max-width:900px;margin:0 auto;transition:opacity .2s';
            document.body.appendChild(el);
          }
          el.textContent = texte;
          el.style.opacity = '1';
          clearTimeout(window.__demoNarrTimer);
          window.__demoNarrTimer = setTimeout(() => {
            el.style.opacity = '0';
          }, ms);
        },
        { texte, ms },
      )
      .catch(() => {});
    await this.page.waitForTimeout(ms + RHYTHM_MS);
  }

  async aller(url) {
    await this.page.goto(url, { waitUntil: 'networkidle' });
    await this._tempo();
  }

  async saisir(sel, texte) {
    await this.page.locator(sel).first().fill(String(texte));
    await this._tempo();
  }

  async cliquer(sel) {
    await this.page.locator(sel).first().click({ timeout: 15000 });
    await this._tempo();
  }

  async cocher(sel) {
    await this.page.locator(sel).first().check({ force: true });
    await this._tempo();
  }
}

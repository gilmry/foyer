// Couche réseau de l'îlot : fetch + gestion d'erreur. Aucune URL d'endpoint en dur ici —
// les chemins et les types viennent du client généré (src/generated/api.ts, issu d'OpenAPI).
import type { Transport } from './generated/api';

export function createBrowserTransport(): Transport {
  return async (url, options = {}) => {
    const res = await fetch(url, {
      method: options.method ?? 'GET',
      credentials: 'same-origin',
      headers: { 'Content-Type': 'application/json', ...(options.headers ?? {}) },
      body: options.body,
    });
    const text = await res.text();
    let data: unknown = null;
    if (text) {
      try {
        data = JSON.parse(text);
      } catch {
        data = text;
      }
    }
    if (!res.ok) {
      const errs = (data as { errors?: string[] })?.errors;
      const msg =
        (Array.isArray(errs) && errs.length ? errs.join(' ') : null) ??
        (data as { error?: string })?.error ??
        `HTTP ${res.status}`;
      throw new Error(msg);
    }
    return data;
  };
}

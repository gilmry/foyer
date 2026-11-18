// Couche réseau de l'îlot : fetch + gestion d'erreur. Aucune URL d'endpoint en dur ici —
// les chemins et les types viennent du client généré (src/generated/api.ts, issu d'OpenAPI).
// `credentials: 'same-origin'` : le navigateur joint le cookie de session (HttpOnly, donc
// invisible de ce script) aux seules requêtes vers notre propre origine.
import type { Transport } from './generated/api';

/** Erreur d'API : porte le code HTTP, pour distinguer « non connecté » (401) du reste. */
export class ApiError extends Error {
  status: number;
  constructor(status: number, message: string) {
    super(message);
    this.status = status;
  }
}

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
      throw new ApiError(res.status, msg);
    }
    return data;
  };
}

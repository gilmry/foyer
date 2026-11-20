// Couche réseau de l'îlot : fetch + gestion d'erreur. Aucune URL d'endpoint en dur ici —
// les chemins et les types viennent du client généré (src/generated/api.ts, issu d'OpenAPI).
import type { Problem, Transport } from './generated/api';

/** Erreur de l'API : porte le code HTTP, pour que l'îlot distingue « non connecté » (401) du reste. */
export class ApiError extends Error {
  constructor(
    public readonly status: number,
    message: string,
  ) {
    super(message);
  }
}

/** Message lisible d'une erreur au format problème (RFC 9457). */
function messageOf(status: number, data: unknown): string {
  const problem = (data ?? {}) as Partial<Problem>;
  const violations = Array.isArray(problem.violations) ? problem.violations.map((v) => v.message) : [];
  if (violations.length) return violations.join(' ');
  return problem.detail ?? problem.title ?? `HTTP ${status}`;
}

/**
 * Transport du navigateur.
 * - Session : le cookie part tout seul (`credentials: 'same-origin'`) ; le navigateur joint
 *   l'en-tête Origin aux requêtes non sûres, que l'API contrôle (protection CSRF).
 * - Jeton porteur : `getToken` le fournit ; il n'est gardé qu'en mémoire, le temps de la page.
 */
export function createBrowserTransport(getToken: () => string | null = () => null): Transport {
  return async (url, options = {}) => {
    const token = getToken();
    const res = await fetch(url, {
      method: options.method ?? 'GET',
      credentials: 'same-origin',
      headers: {
        'Content-Type': 'application/json',
        Accept: 'application/json',
        ...(token ? { Authorization: `Bearer ${token}` } : {}),
        ...(options.headers ?? {}),
      },
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
    if (!res.ok) throw new ApiError(res.status, messageOf(res.status, data));
    return data;
  };
}

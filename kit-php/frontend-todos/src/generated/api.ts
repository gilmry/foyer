// GÉNÉRÉ depuis openapi/todos.openapi.json par frontend-todos/scripts/gen-api.mjs.
// NE PAS ÉDITER À LA MAIN — regénéré par `npm run prebuild` ; le gate contrat vérifie sa fraîcheur.

export type Transport = (
  url: string,
  options?: { method?: string; body?: string; headers?: Record<string, string> },
) => Promise<unknown>;

export interface TodoView {
  id: string;
  title: string;
  done: boolean;
  createdAt: string;
  updatedAt: string;
}

export interface TodoCreateInput {
  title: string;
}

export interface Credentials {
  email: string;
  password: string;
}

export interface Account {
  id: string;
  email: string;
}

export interface IssuedToken {
  token: string;
  expiresAt: string;
}

export interface Health {
  status: string;
  version: string;
  http: 'apiplatform' | 'vanilla';
  persistence: 'cqrs' | 'doctrine';
  auth: ('session' | 'bearer')[];
  registration: 'open' | 'closed';
}

export interface Violation {
  propertyPath: string;
  message: string;
}

export interface Problem {
  type: string;
  title: string;
  status: number;
  detail?: string;
  violations?: Violation[];
}

export interface Registration {
  status: 'accepted';
}

// Schémas de sécurité du contrat (components.securitySchemes).
export const securitySchemes = {
  sessionCookie: { type: 'apiKey', in: 'cookie', name: 'kit_session' },
  bearerToken: { type: 'http', scheme: 'bearer' },
} as const;

// Par opération : les schémas qui l'ouvrent (l'un OU l'autre). Vide = opération publique.
export const operationSecurity = {
  health: [],
  me: ['sessionCookie', 'bearerToken'],
  login: [],
  logout: ['sessionCookie'],
  register: [],
  issueToken: [],
  revokeToken: ['bearerToken'],
  listTodos: ['sessionCookie', 'bearerToken'],
  createTodo: ['sessionCookie', 'bearerToken'],
  getTodo: ['sessionCookie', 'bearerToken'],
  toggleTodo: ['sessionCookie', 'bearerToken'],
  deleteTodo: ['sessionCookie', 'bearerToken'],
} as const;

function queryString(params: Record<string, string | number | undefined>): string {
  const pairs = Object.entries(params)
    .filter(([, v]) => v !== undefined)
    .map(([k, v]) => `${encodeURIComponent(k)}=${encodeURIComponent(String(v))}`);
  return pairs.length ? `?${pairs.join('&')}` : '';
}

export function createTodosClient(transport: Transport) {
  return {
    health: (): Promise<Health> =>
      transport(`api/health`, { method: 'GET' }) as Promise<Health>,
    me: (): Promise<Account> =>
      transport(`api/me`, { method: 'GET' }) as Promise<Account>,
    login: (input: Credentials): Promise<Account> =>
      transport(`api/login`, { method: 'POST', body: JSON.stringify(input) }) as Promise<Account>,
    logout: (): Promise<void> =>
      transport(`api/logout`, { method: 'POST' }) as Promise<void>,
    register: (input: Credentials): Promise<Registration> =>
      transport(`api/register`, { method: 'POST', body: JSON.stringify(input) }) as Promise<Registration>,
    issueToken: (input: Credentials): Promise<IssuedToken> =>
      transport(`api/tokens`, { method: 'POST', body: JSON.stringify(input) }) as Promise<IssuedToken>,
    revokeToken: (): Promise<void> =>
      transport(`api/tokens/current`, { method: 'DELETE' }) as Promise<void>,
    listTodos: (params: { limit?: number; offset?: number } = {}): Promise<TodoView[]> =>
      transport(`api/todos${queryString(params)}`, { method: 'GET' }) as Promise<TodoView[]>,
    createTodo: (input: TodoCreateInput): Promise<TodoView> =>
      transport(`api/todos`, { method: 'POST', body: JSON.stringify(input) }) as Promise<TodoView>,
    getTodo: (id: string): Promise<TodoView> =>
      transport(`api/todos/${encodeURIComponent(id)}`, { method: 'GET' }) as Promise<TodoView>,
    toggleTodo: (id: string): Promise<TodoView> =>
      transport(`api/todos/${encodeURIComponent(id)}`, { method: 'PATCH' }) as Promise<TodoView>,
    deleteTodo: (id: string): Promise<void> =>
      transport(`api/todos/${encodeURIComponent(id)}`, { method: 'DELETE' }) as Promise<void>,
  };
}

// GÉNÉRÉ depuis openapi/todos.openapi.json par frontend-todos/scripts/gen-api.mjs.
// NE PAS ÉDITER À LA MAIN — regénéré par `npm run prebuild` ; le gate contrat vérifie sa fraîcheur.

export type Transport = (
  url: string,
  options?: { method?: string; body?: string; headers?: Record<string, string> },
) => Promise<unknown>;

export interface AccountView {
  id: string;
  email: string;
}

export interface CredentialsInput {
  email: string;
  password: string;
}

export interface DeleteResult {
  deleted: boolean;
}

export interface Error {
  error: string;
}

export interface ErrorList {
  errors: string[];
}

export interface HTTPValidationError {
  detail?: ValidationError[];
}

export interface Health {
  status: string;
}

export interface LogoutResult {
  loggedOut: boolean;
}

export interface TodoCreateInput {
  title: string;
}

export interface TodoList {
  items: TodoView[];
}

export interface TodoView {
  id: string;
  title: string;
  done: boolean;
  createdAt: string;
  updatedAt: string;
}

export interface TokenView {
  token: string;
  tokenType: string;
  expiresAt: string;
}

export interface ValidationError {
  loc: (string | number)[];
  msg: string;
  type: string;
  input?: unknown;
  ctx?: unknown;
}

/** Schémas de sécurité du contrat (components.securitySchemes). */
export const securitySchemes = {
  "bearerAuth": {
    "type": "http",
    "description": "Jeton opaque délivré par POST /api/auth/token.",
    "scheme": "bearer"
  },
  "sessionCookie": {
    "type": "apiKey",
    "description": "Session du front, posée par POST /api/auth/login (HttpOnly, SameSite=Strict, Secure).",
    "in": "cookie",
    "name": "__Host-todo_session"
  }
} as const;

/** Schémas acceptés par opération ; liste vide = opération ouverte. */
export const operationSecurity = {
  "health": [],
  "register": [],
  "login": [],
  "issueToken": [],
  "logout": [
    "bearerAuth",
    "sessionCookie"
  ],
  "me": [
    "bearerAuth",
    "sessionCookie"
  ],
  "listTodos": [
    "bearerAuth",
    "sessionCookie"
  ],
  "createTodo": [
    "bearerAuth",
    "sessionCookie"
  ],
  "getTodo": [
    "bearerAuth",
    "sessionCookie"
  ],
  "toggleTodo": [
    "bearerAuth",
    "sessionCookie"
  ],
  "deleteTodo": [
    "bearerAuth",
    "sessionCookie"
  ]
} as const;

export interface ClientOptions {
  /** Jeton porteur d'un client d'API. Sans lui, l'identité est le cookie de session du navigateur. */
  bearerToken?: string;
}

export function createTodosClient(transport: Transport, options: ClientOptions = {}) {
  const bearer = (): Record<string, string> | undefined =>
    options.bearerToken ? { Authorization: `Bearer ${options.bearerToken}` } : undefined;
  return {
    health: (): Promise<Health> =>
      transport(`api/health`, { method: 'GET' }) as Promise<Health>,
    register: (input: CredentialsInput): Promise<AccountView> =>
      transport(`api/auth/register`, { method: 'POST', body: JSON.stringify(input) }) as Promise<AccountView>,
    login: (input: CredentialsInput): Promise<AccountView> =>
      transport(`api/auth/login`, { method: 'POST', body: JSON.stringify(input) }) as Promise<AccountView>,
    issueToken: (input: CredentialsInput): Promise<TokenView> =>
      transport(`api/auth/token`, { method: 'POST', body: JSON.stringify(input) }) as Promise<TokenView>,
    logout: (): Promise<LogoutResult> =>
      transport(`api/auth/logout`, { method: 'POST', headers: bearer() }) as Promise<LogoutResult>,
    me: (): Promise<AccountView> =>
      transport(`api/auth/me`, { method: 'GET', headers: bearer() }) as Promise<AccountView>,
    listTodos: (): Promise<TodoList> =>
      transport(`api/todos`, { method: 'GET', headers: bearer() }) as Promise<TodoList>,
    createTodo: (input: TodoCreateInput): Promise<TodoView> =>
      transport(`api/todos`, { method: 'POST', body: JSON.stringify(input), headers: bearer() }) as Promise<TodoView>,
    getTodo: (id: string): Promise<TodoView> =>
      transport(`api/todos/${encodeURIComponent(id)}`, { method: 'GET', headers: bearer() }) as Promise<TodoView>,
    toggleTodo: (id: string): Promise<TodoView> =>
      transport(`api/todos/${encodeURIComponent(id)}`, { method: 'PATCH', headers: bearer() }) as Promise<TodoView>,
    deleteTodo: (id: string): Promise<DeleteResult> =>
      transport(`api/todos/${encodeURIComponent(id)}`, { method: 'DELETE', headers: bearer() }) as Promise<DeleteResult>,
  };
}

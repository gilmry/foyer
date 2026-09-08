// GÉNÉRÉ depuis openapi/todos.openapi.json par frontend-todos/scripts/gen-api.mjs.
// NE PAS ÉDITER À LA MAIN — regénéré par `npm run prebuild` ; le gate contrat vérifie sa fraîcheur.

export type Transport = (
  url: string,
  options?: { method?: string; body?: string; headers?: Record<string, string> },
) => Promise<unknown>;

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

export interface ValidationError {
  loc: (string | number)[];
  msg: string;
  type: string;
}

export function createTodosClient(transport: Transport) {
  return {
    listTodos: (): Promise<TodoList> =>
      transport(`api/todos`, { method: 'GET' }) as Promise<TodoList>,
    createTodo: (input: TodoCreateInput): Promise<TodoView> =>
      transport(`api/todos`, { method: 'POST', body: JSON.stringify(input) }) as Promise<TodoView>,
    toggleTodo: (id: string): Promise<TodoView> =>
      transport(`api/todos/${encodeURIComponent(id)}`, { method: 'PATCH' }) as Promise<TodoView>,
    deleteTodo: (id: string): Promise<DeleteResult> =>
      transport(`api/todos/${encodeURIComponent(id)}`, { method: 'DELETE' }) as Promise<DeleteResult>,
  };
}

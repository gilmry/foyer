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

export interface Error {
  error?: string;
}

export interface ErrorList {
  errors?: string[];
}

export function createTodosClient(transport: Transport) {
  return {
    listTodos: (): Promise<{
  items: TodoView[];
}> =>
      transport(`api/todos`, { method: 'GET' }) as Promise<{
  items: TodoView[];
}>,
    createTodo: (input: TodoCreateInput): Promise<TodoView> =>
      transport(`api/todos`, { method: 'POST', body: JSON.stringify(input) }) as Promise<TodoView>,
    toggleTodo: (id: string): Promise<TodoView> =>
      transport(`api/todos/${encodeURIComponent(id)}`, { method: 'PATCH' }) as Promise<TodoView>,
    deleteTodo: (id: string): Promise<{
  deleted?: boolean;
}> =>
      transport(`api/todos/${encodeURIComponent(id)}`, { method: 'DELETE' }) as Promise<{
  deleted?: boolean;
}>,
  };
}

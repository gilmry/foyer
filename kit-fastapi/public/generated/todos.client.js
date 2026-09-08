// GÉNÉRÉ depuis openapi/todos.openapi.json — NE PAS ÉDITER À LA MAIN (gate contrat).
function createTodosClient(transport) {
  return {
    listTodos: function () {
      return transport(`api/todos`, { method: 'GET' });
    },
    createTodo: function (input) {
      return transport(`api/todos`, { method: 'POST', body: JSON.stringify(input) });
    },
    toggleTodo: function (id) {
      return transport(`api/todos/${encodeURIComponent(id)}`, { method: 'PATCH' });
    },
    deleteTodo: function (id) {
      return transport(`api/todos/${encodeURIComponent(id)}`, { method: 'DELETE' });
    },
  };
}
if (typeof window !== 'undefined') { window.createTodosClient = createTodosClient; }
if (typeof module !== 'undefined') { module.exports = { createTodosClient }; }

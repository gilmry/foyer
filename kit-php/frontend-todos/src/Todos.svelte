<script>
  import { onMount } from 'svelte';
  import { createBrowserTransport } from './transport';
  import { createTodosClient } from './generated/api';

  // Client généré et TYPÉ (issu d'OpenAPI) = seule porte d'accès à l'API todos.
  const client = createTodosClient(createBrowserTransport());

  let todos = $state([]);
  let title = $state('');
  let error = $state('');

  async function load() {
    if (!client) return;
    try {
      const data = await client.listTodos();
      todos = Array.isArray(data?.items) ? data.items : [];
      error = '';
    } catch (e) {
      error = e?.message ?? 'Erreur de chargement';
    }
  }

  async function onCreate(ev) {
    ev.preventDefault();
    if (title.trim() === '') return;
    try {
      await client.createTodo({ title });
      title = '';
      await load();
    } catch (e) {
      error = e?.message ?? 'Erreur';
    }
  }

  async function onToggle(id) {
    try {
      await client.toggleTodo(id);
      await load();
    } catch (e) {
      error = e?.message ?? 'Erreur';
    }
  }

  async function onDelete(id) {
    try {
      await client.deleteTodo(id);
      await load();
    } catch (e) {
      error = e?.message ?? 'Erreur';
    }
  }

  onMount(load);
</script>

<section class="todos">
  <h1>Mes tâches</h1>

  <form onsubmit={onCreate}>
    <input
      type="text"
      bind:value={title}
      placeholder="Nouvelle tâche…"
      aria-label="Libellé de la tâche"
    />
    <button type="submit">Ajouter</button>
  </form>

  {#if error}
    <p class="error" role="alert">{error}</p>
  {/if}

  {#if todos.length === 0}
    <p class="empty">Aucune tâche pour l'instant.</p>
  {:else}
    <ul>
      {#each todos as todo (todo.id)}
        <li class:done={todo.done}>
          <label>
            <input type="checkbox" checked={todo.done} onchange={() => onToggle(todo.id)} />
            <!-- Le libellé est rendu comme texte (Svelte échappe par défaut → anti-XSS). -->
            <span>{todo.title}</span>
          </label>
          <button type="button" class="delete" onclick={() => onDelete(todo.id)} aria-label="Supprimer">
            ✕
          </button>
        </li>
      {/each}
    </ul>
  {/if}
</section>

<style>
  .todos { max-width: 32rem; margin: 2rem auto; font-family: system-ui, sans-serif; }
  form { display: flex; gap: 0.5rem; margin-bottom: 1rem; }
  input[type='text'] { flex: 1; padding: 0.5rem; }
  ul { list-style: none; padding: 0; }
  li { display: flex; align-items: center; justify-content: space-between; padding: 0.4rem 0; border-bottom: 1px solid #eee; }
  li.done span { text-decoration: line-through; color: #999; }
  .delete { background: none; border: none; cursor: pointer; color: #c00; }
  .error { color: #c00; }
  .empty { color: #777; }
</style>

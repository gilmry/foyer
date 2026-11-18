<script>
  import { onMount } from 'svelte';
  import { createBrowserTransport } from './transport';
  import { createTodosClient } from './generated/api';

  // Client généré et TYPÉ (issu d'OpenAPI) = seule porte d'accès à l'API. L'identité est le
  // cookie de session posé par l'API à la connexion : ce script ne voit ni ne stocke aucun jeton.
  const client = createTodosClient(createBrowserTransport());

  let ready = $state(false); // l'état de connexion est-il connu ?
  let account = $state(null); // { id, email } une fois connecté
  let mode = $state('login'); // 'login' | 'register'
  let email = $state('');
  let password = $state('');
  let todos = $state([]);
  let title = $state('');
  let error = $state('');

  // Toute réponse 401 ramène au formulaire de connexion (session échue ou révoquée).
  function onFailure(e, fallback) {
    if (e?.status === 401 && account) {
      account = null;
      todos = [];
      error = 'Votre session a expiré. Reconnectez-vous.';
    } else {
      error = e?.message ?? fallback;
    }
  }

  async function load() {
    try {
      const data = await client.listTodos();
      todos = Array.isArray(data?.items) ? data.items : [];
      error = '';
    } catch (e) {
      onFailure(e, 'Erreur de chargement');
    }
  }

  async function start() {
    try {
      account = await client.me();
      await load();
    } catch (e) {
      account = null; // 401 : personne n'est connecté, on montre le formulaire
      if (e?.status !== 401) error = e?.message ?? 'Erreur de chargement';
    }
    ready = true;
  }

  async function onAuth(ev) {
    ev.preventDefault();
    try {
      if (mode === 'register') await client.register({ email, password });
      account = await client.login({ email, password });
      password = '';
      error = '';
      await load();
    } catch (e) {
      password = '';
      error = e?.message ?? 'Erreur';
    }
  }

  async function onLogout() {
    try {
      await client.logout();
    } catch {
      // déjà déconnecté côté serveur : le résultat est le même pour l'utilisateur
    }
    account = null;
    todos = [];
    error = '';
  }

  function switchMode() {
    mode = mode === 'login' ? 'register' : 'login';
    error = '';
  }

  async function onCreate(ev) {
    ev.preventDefault();
    if (title.trim() === '') return;
    try {
      await client.createTodo({ title });
      title = '';
      await load();
    } catch (e) {
      onFailure(e, 'Erreur');
    }
  }

  async function onToggle(id) {
    try {
      await client.toggleTodo(id);
      await load();
    } catch (e) {
      onFailure(e, 'Erreur');
    }
  }

  async function onDelete(id) {
    try {
      await client.deleteTodo(id);
      await load();
    } catch (e) {
      onFailure(e, 'Erreur');
    }
  }

  onMount(start);
</script>

<section class="todos">
  {#if !ready}
    <p class="empty">Chargement…</p>
  {:else if !account}
    <h1>{mode === 'login' ? 'Connexion' : 'Créer un compte'}</h1>

    <form class="auth" onsubmit={onAuth}>
      <label>
        Courriel
        <input type="email" bind:value={email} autocomplete="username" required />
      </label>
      <label>
        Mot de passe
        <input
          type="password"
          bind:value={password}
          autocomplete={mode === 'login' ? 'current-password' : 'new-password'}
          minlength={mode === 'login' ? undefined : 12}
          required
        />
      </label>
      {#if mode === 'register'}
        <p class="hint">Douze caractères au moins.</p>
      {/if}
      <button type="submit">{mode === 'login' ? 'Se connecter' : 'Créer le compte'}</button>
    </form>

    {#if error}
      <p class="error" role="alert">{error}</p>
    {/if}

    <button type="button" class="switch" onclick={switchMode}>
      {mode === 'login' ? 'Pas encore de compte ? Créer un compte' : 'Déjà un compte ? Se connecter'}
    </button>
  {:else}
    <header>
      <h1>Mes tâches</h1>
      <p class="who">
        <!-- Rendu comme texte (Svelte échappe par défaut → anti-XSS). -->
        <span>{account.email}</span>
        <button type="button" class="logout" onclick={onLogout}>Se déconnecter</button>
      </p>
    </header>

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
  {/if}
</section>

<style>
  .todos { max-width: 32rem; margin: 2rem auto; font-family: system-ui, sans-serif; }
  header { display: flex; align-items: baseline; justify-content: space-between; gap: 1rem; }
  .who { display: flex; align-items: baseline; gap: 0.75rem; margin: 0; color: #555; font-size: 0.9rem; }
  form { display: flex; gap: 0.5rem; margin-bottom: 1rem; }
  form.auth { flex-direction: column; gap: 0.75rem; }
  form.auth label { display: flex; flex-direction: column; gap: 0.25rem; }
  form.auth input { padding: 0.5rem; }
  form.auth button { align-self: flex-start; padding: 0.5rem 1rem; }
  input[type='text'] { flex: 1; padding: 0.5rem; }
  ul { list-style: none; padding: 0; }
  li { display: flex; align-items: center; justify-content: space-between; padding: 0.4rem 0; border-bottom: 1px solid #eee; }
  li.done span { text-decoration: line-through; color: #999; }
  .delete { background: none; border: none; cursor: pointer; color: #c00; }
  .logout, .switch { background: none; border: none; padding: 0; cursor: pointer; color: #06c; text-decoration: underline; font: inherit; }
  .error { color: #c00; }
  .empty, .hint { color: #777; }
  .hint { margin: 0; font-size: 0.85rem; }
</style>

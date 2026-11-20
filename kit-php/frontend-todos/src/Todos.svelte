<script>
  import { onMount } from 'svelte';
  import { ApiError, createBrowserTransport } from './transport';
  import { createTodosClient } from './generated/api';

  // Jeton porteur éventuel : en mémoire seulement, jamais dans le stockage du navigateur.
  let token = null;

  // Client généré et TYPÉ (issu d'OpenAPI) = seule porte d'accès à l'API.
  const client = createTodosClient(createBrowserTransport(() => token));

  // 'chargement' → 'connexion' (l'API a répondu 401) ou 'pret'.
  let vue = $state('chargement');
  // Ce que l'adaptateur HTTP servi sait faire, d'après la sonde : session (formulaire de
  // connexion) ou jeton porteur seulement (champ de jeton) ; inscription ouverte ou non.
  let parSession = $state(true);
  let inscriptionOuverte = $state(false);
  let inscription = $state(false);

  let compte = $state(null);
  let todos = $state([]);
  let title = $state('');
  let email = $state('');
  let password = $state('');
  let jeton = $state('');
  let error = $state('');

  /** Toute réponse 401 ramène au formulaire de connexion. */
  function echec(e) {
    if (e instanceof ApiError && e.status === 401) {
      token = null;
      compte = null;
      todos = [];
      vue = 'connexion';
      error = '';
      return;
    }
    error = e?.message ?? 'Erreur';
  }

  async function demarrer() {
    try {
      const sante = await client.health();
      parSession = sante.auth.includes('session');
      inscriptionOuverte = sante.registration === 'open';
    } catch (e) {
      error = e?.message ?? 'Service indisponible';
    }
    await ouvrir();
  }

  async function ouvrir() {
    try {
      compte = await client.me();
      vue = 'pret';
      error = '';
      await load();
    } catch (e) {
      echec(e);
    }
  }

  async function load() {
    try {
      todos = await client.listTodos({ limit: 100 });
      error = '';
    } catch (e) {
      echec(e);
    }
  }

  async function onConnexion(ev) {
    ev.preventDefault();
    error = '';
    try {
      if (!parSession) {
        token = jeton.trim();
        jeton = '';
      } else {
        if (inscription) await client.register({ email, password });
        await client.login({ email, password });
        password = '';
      }
      await ouvrir();
      if (vue !== 'pret' && !error) error = parSession ? 'Identifiants refusés.' : 'Jeton refusé.';
    } catch (e) {
      // Ici, 401 = identifiants refusés : on reste sur le formulaire, avec le message de l'API.
      error = e?.message ?? 'Erreur';
    }
  }

  async function onDeconnexion() {
    try {
      if (parSession) await client.logout();
    } catch {
      // Session déjà fermée : rien à faire de plus.
    }
    token = null;
    compte = null;
    todos = [];
    error = '';
    vue = 'connexion';
  }

  async function onCreate(ev) {
    ev.preventDefault();
    if (title.trim() === '') return;
    try {
      await client.createTodo({ title });
      title = '';
      await load();
    } catch (e) {
      echec(e);
    }
  }

  async function onToggle(id) {
    try {
      await client.toggleTodo(id);
      await load();
    } catch (e) {
      echec(e);
    }
  }

  async function onDelete(id) {
    try {
      await client.deleteTodo(id);
      await load();
    } catch (e) {
      echec(e);
    }
  }

  onMount(demarrer);
</script>

<section class="todos">
  <h1>Mes tâches</h1>

  {#if vue === 'connexion'}
    <form class="auth" onsubmit={onConnexion}>
      {#if parSession}
        <p class="hint">{inscription ? 'Créer un compte' : 'Connectez-vous pour voir vos tâches.'}</p>
        <input type="email" bind:value={email} placeholder="Courriel" aria-label="Courriel" autocomplete="username" required />
        <input
          type="password"
          bind:value={password}
          placeholder={inscription ? 'Mot de passe (12 caractères au moins)' : 'Mot de passe'}
          aria-label="Mot de passe"
          autocomplete={inscription ? 'new-password' : 'current-password'}
          required
        />
        <button type="submit">{inscription ? 'Créer le compte' : 'Se connecter'}</button>
        {#if inscriptionOuverte}
          <button type="button" class="link" onclick={() => { inscription = !inscription; error = ''; }}>
            {inscription ? 'J\'ai déjà un compte' : 'Créer un compte'}
          </button>
        {/if}
      {:else}
        <p class="hint">Collez un jeton d'accès pour voir vos tâches.</p>
        <input type="password" bind:value={jeton} placeholder="Jeton d'accès" aria-label="Jeton d'accès" autocomplete="off" required />
        <button type="submit">Utiliser ce jeton</button>
      {/if}
    </form>
  {:else if vue === 'pret'}
    <p class="session">
      <span>{compte?.email}</span>
      <button type="button" class="link logout" onclick={onDeconnexion}>Se déconnecter</button>
    </p>

    <form class="create" onsubmit={onCreate}>
      <input
        type="text"
        bind:value={title}
        placeholder="Nouvelle tâche…"
        aria-label="Libellé de la tâche"
      />
      <button type="submit">Ajouter</button>
    </form>
  {/if}

  {#if error}
    <p class="error" role="alert">{error}</p>
  {/if}

  {#if vue === 'pret'}
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
  form.create { display: flex; gap: 0.5rem; margin-bottom: 1rem; }
  form.auth { display: flex; flex-direction: column; gap: 0.5rem; margin-bottom: 1rem; }
  input[type='text'] { flex: 1; padding: 0.5rem; }
  input[type='email'], input[type='password'] { padding: 0.5rem; }
  button[type='submit'] { padding: 0.5rem 0.75rem; }
  ul { list-style: none; padding: 0; }
  li { display: flex; align-items: center; justify-content: space-between; padding: 0.4rem 0; border-bottom: 1px solid #eee; }
  li.done span { text-decoration: line-through; color: #999; }
  .delete { background: none; border: none; cursor: pointer; color: #c00; }
  .link { background: none; border: none; cursor: pointer; color: #06c; padding: 0; text-align: left; }
  .session { display: flex; justify-content: space-between; align-items: center; color: #555; font-size: 0.9rem; margin: 0 0 1rem; }
  .hint { color: #555; margin: 0; }
  .error { color: #c00; }
  .empty { color: #777; }
</style>

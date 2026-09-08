import { mount } from 'svelte';
import Todos from './Todos.svelte';

// Hydrate l'îlot dans le conteneur prévu par la page.
const target = document.getElementById('todoSection');
if (target) {
  target.textContent = '';
  mount(Todos, { target });
}

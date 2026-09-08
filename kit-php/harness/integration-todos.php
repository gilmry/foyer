<?php

declare(strict_types=1);

/**
 * Gate `integration` — exerce le vrai PdoTodoRepository + les use-cases contre MySQL.
 * Applique la migration, déroule create/list/toggle/delete, vérifie la persistance.
 * Lancé par harness/run-integration.sh (MySQL éphémère via Docker).
 */
require __DIR__ . '/../src/bootstrap.php';

use TodoApp\Adapter\Todo\PdoTodoRepository;
use TodoApp\Adapter\Todo\RealClock;
use TodoApp\Adapter\Todo\UuidGenerator;
use TodoApp\Application\Todo\CreateTodo;
use TodoApp\Application\Todo\DeleteTodo;
use TodoApp\Application\Todo\ListTodos;
use TodoApp\Application\Todo\ToggleTodo;
use TodoApp\Database;

$config = [
    'db' => [
        'host' => getenv('DB_HOST') ?: '127.0.0.1',
        'port' => (int) (getenv('DB_PORT') ?: 13306),
        'database' => getenv('DB_NAME') ?: 'todo',
        'username' => getenv('DB_USER') ?: 'root',
        'password' => getenv('DB_PASSWORD') ?: 'root',
        'charset' => 'utf8mb4',
    ],
];

$assertions = 0;
$failures = 0;
function check(string $label, bool $cond): void
{
    global $assertions, $failures;
    $assertions++;
    if ($cond) {
        fwrite(STDOUT, "  ✓ $label\n");
    } else {
        $failures++;
        fwrite(STDERR, "  ✗ $label\n");
    }
}

$db = Database::connect($config);

// Migration up (réversible) — état propre.
$db->exec('DROP TABLE IF EXISTS todos');
$db->exec((string) file_get_contents(__DIR__ . '/../database/migrations/pending/0001_create_todos.up.sql'));

$repo = new PdoTodoRepository($db);
$clock = new RealClock();
$ids = new UuidGenerator();

// @happy — create persiste
$todo = (new CreateTodo($repo, $clock, $ids))->execute(['title' => 'acheter du pain']);
check('create → tâche persistée et relisible', $repo->find($todo->id()) !== null);
check('create → statut initial « à faire »', $repo->find($todo->id())->isDone() === false);

// list
$items = (new ListTodos($repo))->execute();
check('list → 1 élément', count($items) === 1);
check('list → libellé correct', $items[0]['title'] === 'acheter du pain');

// @happy — toggle persiste
(new ToggleTodo($repo, $clock))->execute($todo->id());
check('toggle → statut « faite » persisté (survit à la relecture)', $repo->find($todo->id())->isDone() === true);

// @edge — persistance : nouvelle connexion, l'état survit
$db2 = Database::connect($config);
$repo2 = new PdoTodoRepository($db2);
check('persistance → visible depuis une nouvelle connexion', $repo2->find($todo->id())?->isDone() === true);

// @happy — delete
(new DeleteTodo($repo))->execute($todo->id());
check('delete → tâche absente', $repo->find($todo->id()) === null);
check('delete → liste vide', (new ListTodos($repo))->execute() === []);

// Migration down (réversibilité réelle)
$db->exec((string) file_get_contents(__DIR__ . '/../database/migrations/pending/0001_create_todos.down.sql'));
$stmt = $db->query("SHOW TABLES LIKE 'todos'");
check('migration down → table supprimée', $stmt->fetch() === false);

fwrite(STDOUT, sprintf("\nintegration: %s (%d assertions, %d échecs)\n", $failures === 0 ? '🟢' : '🔴', $assertions, $failures));
exit($failures === 0 ? 0 : 1);

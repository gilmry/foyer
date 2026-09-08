<?php

declare(strict_types=1);

/**
 * Gate `integration` — exerce les DEUX adaptateurs de persistance (CQRS SQL pur ET Doctrine ORM)
 * contre MySQL réel, via les use-cases. Prouve l'interchangeabilité du port TodoRepository.
 */
require __DIR__ . '/../src/bootstrap.php';
$vendor = __DIR__ . '/../vendor/autoload.php';
if (is_file($vendor)) {
    require_once $vendor;
}

use TodoApp\Adapter\Todo\CqrsTodoRepository;
use TodoApp\Adapter\Todo\Doctrine\EntityManagerFactory;
use TodoApp\Adapter\Todo\DoctrineTodoRepository;
use TodoApp\Adapter\Todo\RealClock;
use TodoApp\Adapter\Todo\UuidGenerator;
use TodoApp\Application\Todo\CreateTodo;
use TodoApp\Application\Todo\DeleteTodo;
use TodoApp\Application\Todo\ListTodos;
use TodoApp\Application\Todo\ToggleTodo;
use TodoApp\Database;
use TodoApp\Domain\Todo\TodoRepository;

$config = ['db' => [
    'host' => getenv('DB_HOST') ?: '127.0.0.1',
    'port' => (int) (getenv('DB_PORT') ?: 13306),
    'database' => getenv('DB_NAME') ?: 'todo',
    'username' => getenv('DB_USER') ?: 'root',
    'password' => getenv('DB_PASSWORD') ?: 'root',
    'charset' => 'utf8mb4',
]];

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

function reset_schema(array $config): void
{
    $db = Database::connect($config);
    $db->exec('DROP TABLE IF EXISTS todos');
    $db->exec((string) file_get_contents(__DIR__ . '/../database/migrations/pending/0001_create_todos.up.sql'));
}

/** @param callable():TodoRepository $repoFactory */
function run(string $kind, array $config, callable $repoFactory): void
{
    fwrite(STDOUT, "\n[$kind]\n");
    reset_schema($config);
    $clock = new RealClock();
    $ids = new UuidGenerator();

    $repo = $repoFactory();
    $todo = (new CreateTodo($repo, $clock, $ids))->execute(['title' => 'acheter du pain']);
    check("$kind: create persiste et relit", $repo->find($todo->id()) !== null);
    check("$kind: statut initial « à faire »", $repo->find($todo->id())->isDone() === false);
    $items = (new ListTodos($repo))->execute();
    check("$kind: list = 1 élément, bon libellé", count($items) === 1 && $items[0]['title'] === 'acheter du pain');
    (new ToggleTodo($repo, $clock))->execute($todo->id());
    check("$kind: toggle persisté (faite)", $repo->find($todo->id())->isDone() === true);

    // Nouvelle instance d'adaptateur : l'état survit (persistance réelle).
    $repo2 = $repoFactory();
    $found = $repo2->findAll();
    check("$kind: persistance inter-instance", count($found) === 1 && $found[0]->isDone() === true);
    (new DeleteTodo($repo2))->execute($found[0]->id());
    check("$kind: delete → liste vide", (new ListTodos($repo2))->execute() === []);
}

run('cqrs', $config, static fn (): TodoRepository => new CqrsTodoRepository(Database::connect($config)));
run('doctrine', $config, static fn (): TodoRepository => new DoctrineTodoRepository(EntityManagerFactory::create($config)));

fwrite(STDOUT, sprintf("\nintegration: %s (%d assertions, %d échecs)\n", $failures === 0 ? '🟢' : '🔴', $assertions, $failures));
exit($failures === 0 ? 0 : 1);

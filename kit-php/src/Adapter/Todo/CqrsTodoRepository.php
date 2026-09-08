<?php

declare(strict_types=1);

namespace TodoApp\Adapter\Todo;

use PDO;
use TodoApp\Domain\Todo\Todo;
use TodoApp\Domain\Todo\TodoRepository;

/**
 * Adaptateur de persistance — option CQRS (SQL pur, PDO/MySQL).
 * Compose le côté lecture (TodoQueries) et écriture (TodoCommands) pour satisfaire le port
 * TodoRepository. Schéma géré par migrations up/down SQL.
 * Interchangeable avec DoctrineTodoRepository via Adapter/Todo/RepositoryFactory.
 */
final class CqrsTodoRepository implements TodoRepository
{
    private TodoQueries $queries;
    private TodoCommands $commands;

    public function __construct(PDO $db)
    {
        $this->queries = new TodoQueries($db);
        $this->commands = new TodoCommands($db);
    }

    public function find(string $id): ?Todo
    {
        return $this->queries->find($id);
    }

    public function findAll(): array
    {
        return $this->queries->findAll();
    }

    public function save(Todo $todo): void
    {
        $this->commands->save($todo);
    }

    public function delete(string $id): void
    {
        $this->commands->delete($id);
    }
}

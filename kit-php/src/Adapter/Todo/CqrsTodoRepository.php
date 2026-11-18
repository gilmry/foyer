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
 * Chaque requête SQL porte `owner_id` : le cloisonnement est dans l'adaptateur.
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

    public function find(string $ownerId, string $id): ?Todo
    {
        return $this->queries->find($ownerId, $id);
    }

    public function findAll(string $ownerId, int $limit, int $offset = 0): array
    {
        return $this->queries->findAll($ownerId, $limit, $offset);
    }

    public function save(string $ownerId, Todo $todo): void
    {
        $this->commands->save($ownerId, $todo);
    }

    public function delete(string $ownerId, string $id): void
    {
        $this->commands->delete($ownerId, $id);
    }
}

<?php

declare(strict_types=1);

namespace TodoApp\Domain\Todo;

/**
 * Port de persistance (interface) — implémenté par des adaptateurs interchangeables
 * (Adapter/Todo/CqrsTodoRepository en SQL pur, ou Adapter/Todo/DoctrineTodoRepository en ORM).
 * Le domaine ne connaît que ce contrat, jamais PDO ni SQL.
 *
 * CLOISONNEMENT : chaque méthode prend le propriétaire. Un adaptateur ne lit, n'écrit ni ne
 * supprime jamais une tâche hors de ce propriétaire ; une tâche d'autrui est « introuvable ».
 */
interface TodoRepository
{
    public function find(string $ownerId, string $id): ?Todo;

    /** @return list<Todo> celles du propriétaire, par date de création croissante, bornées */
    public function findAll(string $ownerId, int $limit, int $offset = 0): array;

    /** @throws OwnershipViolationException si la tâche n'est pas (ou plus) à ce propriétaire */
    public function save(string $ownerId, Todo $todo): void;

    public function delete(string $ownerId, string $id): void;
}

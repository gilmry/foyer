<?php

declare(strict_types=1);

namespace TodoApp\Domain\Todo;

/**
 * Port de persistance (interface) — implémenté par des adaptateurs interchangeables
 * (Adapter/Todo/CqrsTodoRepository en SQL pur, ou Adapter/Todo/DoctrineTodoRepository en ORM).
 * Le domaine ne connaît que ce contrat, jamais PDO ni SQL.
 */
interface TodoRepository
{
    public function find(string $id): ?Todo;

    /** @return list<Todo> ordonnées par date de création croissante */
    public function findAll(): array;

    public function save(Todo $todo): void;

    public function delete(string $id): void;
}

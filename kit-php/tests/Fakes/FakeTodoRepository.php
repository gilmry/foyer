<?php

declare(strict_types=1);

namespace TodoApp\Tests\Fakes;

use TodoApp\Domain\Todo\OwnershipViolationException;
use TodoApp\Domain\Todo\Todo;
use TodoApp\Domain\Todo\TodoRepository;

/** Repository in-memory pour les tests (aucune DB). Cloisonne comme les vrais adaptateurs. */
final class FakeTodoRepository implements TodoRepository
{
    /** @var array<string,Todo> */
    private array $store = [];

    public function find(string $ownerId, string $id): ?Todo
    {
        $todo = $this->store[$id] ?? null;

        return $todo !== null && $todo->ownerId() === $ownerId ? $todo : null;
    }

    public function findAll(string $ownerId, int $limit, int $offset = 0): array
    {
        $all = array_values(array_filter($this->store, static fn (Todo $t): bool => $t->ownerId() === $ownerId));
        usort($all, static fn (Todo $a, Todo $b): int => $a->createdAt() <=> $b->createdAt());

        return array_slice($all, $offset, $limit);
    }

    public function save(string $ownerId, Todo $todo): void
    {
        $existing = $this->store[$todo->id()] ?? null;
        if ($todo->ownerId() !== $ownerId || ($existing !== null && $existing->ownerId() !== $ownerId)) {
            throw new OwnershipViolationException();
        }
        $this->store[$todo->id()] = $todo;
    }

    public function delete(string $ownerId, string $id): void
    {
        if ($this->find($ownerId, $id) !== null) {
            unset($this->store[$id]);
        }
    }

    public function count(): int
    {
        return count($this->store);
    }
}

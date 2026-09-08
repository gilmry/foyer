<?php

declare(strict_types=1);

namespace TodoApp\Tests\Fakes;

use TodoApp\Domain\Todo\Todo;
use TodoApp\Domain\Todo\TodoRepository;

/** Repository in-memory pour les tests (aucune DB). */
final class FakeTodoRepository implements TodoRepository
{
    /** @var array<string,Todo> */
    private array $store = [];

    public function find(string $id): ?Todo
    {
        return $this->store[$id] ?? null;
    }

    public function findAll(): array
    {
        $all = array_values($this->store);
        usort($all, static fn (Todo $a, Todo $b): int => $a->createdAt() <=> $b->createdAt());

        return $all;
    }

    public function save(Todo $todo): void
    {
        $this->store[$todo->id()] = $todo;
    }

    public function delete(string $id): void
    {
        unset($this->store[$id]);
    }

    public function count(): int
    {
        return count($this->store);
    }
}

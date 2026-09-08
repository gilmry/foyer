<?php

declare(strict_types=1);

namespace TodoApp\Adapter\Todo;

use DateTimeImmutable;
use PDO;
use TodoApp\Domain\Todo\Todo;
use TodoApp\Domain\Todo\TodoRepository;

/** Adaptateur de persistance : implémente le port TodoRepository sur MySQL via PDO. */
final class PdoTodoRepository implements TodoRepository
{
    public function __construct(private readonly PDO $db)
    {
    }

    public function find(string $id): ?Todo
    {
        $s = $this->db->prepare('SELECT * FROM todos WHERE id = ? LIMIT 1');
        $s->execute([$id]);
        $row = $s->fetch();

        return $row ? self::map($row) : null;
    }

    public function findAll(): array
    {
        $rows = $this->db->query('SELECT * FROM todos ORDER BY created_at, id')->fetchAll();

        return array_map(static fn (array $row): Todo => self::map($row), $rows);
    }

    public function save(Todo $todo): void
    {
        $exists = $this->find($todo->id()) !== null;
        if ($exists) {
            $this->db->prepare('UPDATE todos SET title = ?, done = ?, updated_at = ? WHERE id = ?')
                ->execute([
                    $todo->title(),
                    $todo->isDone() ? 1 : 0,
                    $todo->updatedAt()->format('Y-m-d H:i:s'),
                    $todo->id(),
                ]);
        } else {
            $this->db->prepare('INSERT INTO todos (id, title, done, created_at, updated_at) VALUES (?, ?, ?, ?, ?)')
                ->execute([
                    $todo->id(),
                    $todo->title(),
                    $todo->isDone() ? 1 : 0,
                    $todo->createdAt()->format('Y-m-d H:i:s'),
                    $todo->updatedAt()->format('Y-m-d H:i:s'),
                ]);
        }
    }

    public function delete(string $id): void
    {
        $this->db->prepare('DELETE FROM todos WHERE id = ?')->execute([$id]);
    }

    /** @param array<string,mixed> $row */
    private static function map(array $row): Todo
    {
        return new Todo(
            (string) $row['id'],
            (string) $row['title'],
            (bool) (int) $row['done'],
            new DateTimeImmutable((string) $row['created_at']),
            new DateTimeImmutable((string) $row['updated_at']),
        );
    }
}

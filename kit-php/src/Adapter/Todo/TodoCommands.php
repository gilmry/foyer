<?php

declare(strict_types=1);

namespace TodoApp\Adapter\Todo;

use PDO;
use TodoApp\Domain\Todo\Todo;

/** CQRS — côté ÉCRITURE (commands), mutations transactionnelles. */
final class TodoCommands
{
    public function __construct(private readonly PDO $db)
    {
    }

    public function save(Todo $todo): void
    {
        $exists = (new TodoQueries($this->db))->find($todo->id()) !== null;
        if ($exists) {
            $this->db->prepare('UPDATE todos SET title = ?, done = ?, updated_at = ? WHERE id = ?')
                ->execute([$todo->title(), $todo->isDone() ? 1 : 0, $todo->updatedAt()->format('Y-m-d H:i:s'), $todo->id()]);
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
}

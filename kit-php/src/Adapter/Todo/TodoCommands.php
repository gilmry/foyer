<?php

declare(strict_types=1);

namespace TodoApp\Adapter\Todo;

use PDO;
use TodoApp\Domain\Todo\OwnershipViolationException;
use TodoApp\Domain\Todo\Todo;

/** CQRS — côté ÉCRITURE (commands). Aucune écriture hors du propriétaire donné. */
final class TodoCommands
{
    public function __construct(private readonly PDO $db)
    {
    }

    public function save(string $ownerId, Todo $todo): void
    {
        if ($todo->ownerId() !== $ownerId) {
            throw new OwnershipViolationException();
        }
        $s = $this->db->prepare('SELECT owner_id FROM todos WHERE id = ? LIMIT 1');
        $s->execute([$todo->id()]);
        $existingOwner = $s->fetchColumn();

        if ($existingOwner === false) {
            $this->db->prepare('INSERT INTO todos (id, owner_id, title, done, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?)')
                ->execute([
                    $todo->id(),
                    $ownerId,
                    $todo->title(),
                    $todo->isDone() ? 1 : 0,
                    $todo->createdAt()->format('Y-m-d H:i:s'),
                    $todo->updatedAt()->format('Y-m-d H:i:s'),
                ]);

            return;
        }
        if ((string) $existingOwner !== $ownerId) {
            throw new OwnershipViolationException();
        }
        $this->db->prepare('UPDATE todos SET title = ?, done = ?, updated_at = ? WHERE id = ? AND owner_id = ?')
            ->execute([$todo->title(), $todo->isDone() ? 1 : 0, $todo->updatedAt()->format('Y-m-d H:i:s'), $todo->id(), $ownerId]);
    }

    public function delete(string $ownerId, string $id): void
    {
        $this->db->prepare('DELETE FROM todos WHERE id = ? AND owner_id = ?')->execute([$id, $ownerId]);
    }
}

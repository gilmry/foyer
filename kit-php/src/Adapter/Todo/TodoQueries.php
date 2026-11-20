<?php

declare(strict_types=1);

namespace TodoApp\Adapter\Todo;

use DateTimeImmutable;
use PDO;
use TodoApp\Domain\Todo\Todo;

/** CQRS — côté LECTURE (queries), aucune mutation. Toujours filtré par propriétaire. */
final class TodoQueries
{
    public function __construct(private readonly PDO $db)
    {
    }

    public function find(string $ownerId, string $id): ?Todo
    {
        $s = $this->db->prepare('SELECT * FROM todos WHERE id = ? AND owner_id = ? LIMIT 1');
        $s->execute([$id, $ownerId]);
        $row = $s->fetch();

        return $row ? self::map($row) : null;
    }

    /** @return list<Todo> */
    public function findAll(string $ownerId, int $limit, int $offset = 0): array
    {
        $s = $this->db->prepare('SELECT * FROM todos WHERE owner_id = ? ORDER BY created_at, id LIMIT ? OFFSET ?');
        $s->bindValue(1, $ownerId);
        $s->bindValue(2, max(0, $limit), PDO::PARAM_INT);
        $s->bindValue(3, max(0, $offset), PDO::PARAM_INT);
        $s->execute();

        return array_map(static fn (array $row): Todo => self::map($row), $s->fetchAll());
    }

    /** @param array<string,mixed> $row */
    private static function map(array $row): Todo
    {
        return new Todo(
            (string) $row['id'],
            (string) $row['owner_id'],
            (string) $row['title'],
            (bool) (int) $row['done'],
            new DateTimeImmutable((string) $row['created_at']),
            new DateTimeImmutable((string) $row['updated_at']),
        );
    }
}

<?php

declare(strict_types=1);

namespace TodoApp\Adapter\Todo;

use DateTimeImmutable;
use PDO;
use TodoApp\Domain\Todo\Todo;

/** CQRS — côté LECTURE (queries), aucune mutation. */
final class TodoQueries
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

    /** @return list<Todo> */
    public function findAll(): array
    {
        $rows = $this->db->query('SELECT * FROM todos ORDER BY created_at, id')->fetchAll();

        return array_map(static fn (array $row): Todo => self::map($row), $rows);
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

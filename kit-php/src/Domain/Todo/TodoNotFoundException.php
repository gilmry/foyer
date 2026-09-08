<?php

declare(strict_types=1);

namespace TodoApp\Domain\Todo;

use RuntimeException;

/** Levée quand un id demandé n'existe pas → mappée en HTTP 404. */
final class TodoNotFoundException extends RuntimeException
{
    public static function withId(string $id): self
    {
        return new self(sprintf('Tâche introuvable : %s.', $id));
    }
}

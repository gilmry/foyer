<?php

declare(strict_types=1);

namespace TodoApp\Domain\Todo;

use RuntimeException;

/**
 * Levée quand un id demandé n'existe pas POUR CE PROPRIÉTAIRE → mappée en HTTP 404.
 * Le message ne dit pas si la tâche existe chez un autre : les deux cas sont indiscernables.
 */
final class TodoNotFoundException extends RuntimeException
{
    public static function withId(string $id): self
    {
        return new self('Tâche introuvable.');
    }
}

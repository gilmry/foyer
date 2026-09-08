<?php

declare(strict_types=1);

namespace TodoApp\Domain\Todo;

use RuntimeException;

/** Levée quand une entrée viole une règle du domaine → mappée en HTTP 400. */
final class TodoValidationException extends RuntimeException
{
    /** @param list<string> $errors */
    public function __construct(private readonly array $errors)
    {
        parent::__construct(implode(' ', $errors));
    }

    /** @return list<string> */
    public function errors(): array
    {
        return $this->errors;
    }
}

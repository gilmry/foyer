<?php

declare(strict_types=1);

namespace TodoApp\Domain\Account;

use RuntimeException;

/** Levée quand un courriel ou un mot de passe viole une règle → mappée en HTTP 422. */
final class AccountValidationException extends RuntimeException
{
    /** @param array<string,string> $errors champ → message */
    public function __construct(private readonly array $errors)
    {
        parent::__construct(implode(' ', $errors));
    }

    /** @return array<string,string> */
    public function errors(): array
    {
        return $this->errors;
    }
}

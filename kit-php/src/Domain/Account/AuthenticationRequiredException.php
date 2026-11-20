<?php

declare(strict_types=1);

namespace TodoApp\Domain\Account;

use RuntimeException;

/** Levée quand un cas d'usage est appelé sans identité → mappée en HTTP 401. */
final class AuthenticationRequiredException extends RuntimeException
{
    public function __construct()
    {
        parent::__construct('Authentification requise.');
    }
}

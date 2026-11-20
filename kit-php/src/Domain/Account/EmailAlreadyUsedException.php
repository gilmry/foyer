<?php

declare(strict_types=1);

namespace TodoApp\Domain\Account;

use RuntimeException;

/** Levée quand le courriel a déjà un compte → mappée en HTTP 409. */
final class EmailAlreadyUsedException extends RuntimeException
{
    public function __construct()
    {
        parent::__construct('Ce courriel a déjà un compte.');
    }
}

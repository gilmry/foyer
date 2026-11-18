<?php

declare(strict_types=1);

namespace TodoApp\Tests\Fakes;

use TodoApp\Domain\Account\AuthenticationRequiredException;
use TodoApp\Domain\Account\CurrentUser;

/** Identité de test : un compte donné, ou personne (null). */
final class FakeCurrentUser implements CurrentUser
{
    public function __construct(public ?string $accountId = 'compte-a')
    {
    }

    public function id(): string
    {
        return $this->accountId ?? throw new AuthenticationRequiredException();
    }
}

<?php

declare(strict_types=1);

namespace TodoApp\Adapter\Account;

use TodoApp\Domain\Account\AuthenticationRequiredException;
use TodoApp\Domain\Account\CurrentUser;

/**
 * Identité déjà établie par l'adaptateur appelant (jeton vérifié par l'adaptateur vanilla, outil
 * en ligne de commande, gate d'intégration). `null` = aucune identité : tout cas d'usage refuse.
 */
final class FixedCurrentUser implements CurrentUser
{
    public function __construct(private readonly ?string $accountId)
    {
    }

    public function id(): string
    {
        return $this->accountId ?? throw new AuthenticationRequiredException();
    }
}

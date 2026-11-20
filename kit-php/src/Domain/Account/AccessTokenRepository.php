<?php

declare(strict_types=1);

namespace TodoApp\Domain\Account;

use DateTimeImmutable;

/** Port de persistance des jetons porteurs — ne voit jamais que leur EMPREINTE. */
interface AccessTokenRepository
{
    public function add(string $tokenHash, string $accountId, DateTimeImmutable $createdAt, DateTimeImmutable $expiresAt): void;

    /** Identifiant du compte si l'empreinte existe et n'est pas échue à $now, sinon null. */
    public function findAccountId(string $tokenHash, DateTimeImmutable $now): ?string;

    public function remove(string $tokenHash): void;

    public function removeExpired(DateTimeImmutable $now): void;
}

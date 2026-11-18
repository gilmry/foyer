<?php

declare(strict_types=1);

namespace TodoApp\Application\Account;

use TodoApp\Domain\Account\AccessTokenRepository;

/** Cas d'usage : révoquer un jeton porteur (le supprimer). */
final class RevokeAccessToken
{
    public function __construct(private readonly AccessTokenRepository $tokens)
    {
    }

    public function execute(string $token): void
    {
        $this->tokens->remove(IssueAccessToken::fingerprint($token));
    }
}

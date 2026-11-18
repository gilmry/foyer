<?php

declare(strict_types=1);

namespace TodoApp\Application\Account;

use TodoApp\Domain\Account\AccessTokenRepository;
use TodoApp\Domain\Todo\Clock;

/** Cas d'usage : retrouver le compte d'un jeton porteur valide (null si inconnu, révoqué ou échu). */
final class ResolveAccessToken
{
    public function __construct(
        private readonly AccessTokenRepository $tokens,
        private readonly Clock $clock,
    ) {
    }

    public function execute(string $token): ?string
    {
        if (!str_starts_with($token, IssueAccessToken::PREFIX) || strlen($token) > 256) {
            return null;
        }

        return $this->tokens->findAccountId(IssueAccessToken::fingerprint($token), $this->clock->now());
    }
}

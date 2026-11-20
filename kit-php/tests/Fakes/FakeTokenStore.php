<?php

declare(strict_types=1);

namespace TodoApp\Tests\Fakes;

use DateTimeImmutable;
use TodoApp\Domain\Account\AccessTokenRepository;

/** Jetons en mémoire pour les tests : comme la vraie table, ne voit que des empreintes. */
final class FakeTokenStore implements AccessTokenRepository
{
    /** @var array<string,array{accountId:string,expiresAt:DateTimeImmutable}> empreinte → ligne */
    public array $tokens = [];

    public function add(string $tokenHash, string $accountId, DateTimeImmutable $createdAt, DateTimeImmutable $expiresAt): void
    {
        $this->tokens[$tokenHash] = ['accountId' => $accountId, 'expiresAt' => $expiresAt];
    }

    public function findAccountId(string $tokenHash, DateTimeImmutable $now): ?string
    {
        $row = $this->tokens[$tokenHash] ?? null;

        return $row !== null && $row['expiresAt'] > $now ? $row['accountId'] : null;
    }

    public function remove(string $tokenHash): void
    {
        unset($this->tokens[$tokenHash]);
    }

    public function removeExpired(DateTimeImmutable $now): void
    {
        $this->tokens = array_filter($this->tokens, static fn (array $row): bool => $row['expiresAt'] > $now);
    }
}

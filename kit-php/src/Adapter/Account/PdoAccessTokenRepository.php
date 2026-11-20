<?php

declare(strict_types=1);

namespace TodoApp\Adapter\Account;

use DateTimeImmutable;
use PDO;
use TodoApp\Domain\Account\AccessTokenRepository;

/** Jetons porteurs en SQL pur : la table ne contient que des empreintes SHA-256. */
final class PdoAccessTokenRepository implements AccessTokenRepository
{
    public function __construct(private readonly PDO $db)
    {
    }

    public function add(string $tokenHash, string $accountId, DateTimeImmutable $createdAt, DateTimeImmutable $expiresAt): void
    {
        $this->db->prepare('INSERT INTO access_tokens (token_hash, account_id, created_at, expires_at) VALUES (?, ?, ?, ?)')
            ->execute([$tokenHash, $accountId, $createdAt->format('Y-m-d H:i:s'), $expiresAt->format('Y-m-d H:i:s')]);
    }

    public function findAccountId(string $tokenHash, DateTimeImmutable $now): ?string
    {
        $s = $this->db->prepare('SELECT account_id FROM access_tokens WHERE token_hash = ? AND expires_at > ? LIMIT 1');
        $s->execute([$tokenHash, $now->format('Y-m-d H:i:s')]);
        $id = $s->fetchColumn();

        return $id === false ? null : (string) $id;
    }

    public function remove(string $tokenHash): void
    {
        $this->db->prepare('DELETE FROM access_tokens WHERE token_hash = ?')->execute([$tokenHash]);
    }

    public function removeExpired(DateTimeImmutable $now): void
    {
        $this->db->prepare('DELETE FROM access_tokens WHERE expires_at <= ?')->execute([$now->format('Y-m-d H:i:s')]);
    }
}

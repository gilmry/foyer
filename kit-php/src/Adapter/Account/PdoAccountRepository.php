<?php

declare(strict_types=1);

namespace TodoApp\Adapter\Account;

use DateTimeImmutable;
use PDO;
use PDOException;
use TodoApp\Domain\Account\Account;
use TodoApp\Domain\Account\AccountRepository;
use TodoApp\Domain\Account\EmailAlreadyUsedException;

/** Comptes en SQL pur (PDO). Voir ADR-001 : pas de double implémentation pour les comptes. */
final class PdoAccountRepository implements AccountRepository
{
    public function __construct(private readonly PDO $db)
    {
    }

    public function findById(string $id): ?Account
    {
        return $this->one('SELECT * FROM accounts WHERE id = ? LIMIT 1', $id);
    }

    public function findByEmail(string $email): ?Account
    {
        $account = $this->one('SELECT * FROM accounts WHERE email = ? LIMIT 1', $email);

        // Ceinture et bretelles : même si la collation de la colonne redevenait insensible aux
        // accents ou à la casse, seul le courriel exactement égal désigne le compte.
        return $account !== null && $account->email() === $email ? $account : null;
    }

    public function add(Account $account): void
    {
        try {
            $this->db->prepare('INSERT INTO accounts (id, email, password_hash, created_at) VALUES (?, ?, ?, ?)')
                ->execute([$account->id(), $account->email(), $account->passwordHash(), $account->createdAt()->format('Y-m-d H:i:s')]);
        } catch (PDOException $e) {
            if ($e->getCode() === '23000') {
                throw new EmailAlreadyUsedException();
            }
            throw $e;
        }
    }

    private function one(string $sql, string $param): ?Account
    {
        $s = $this->db->prepare($sql);
        $s->execute([$param]);
        $row = $s->fetch();

        return $row ? new Account(
            (string) $row['id'],
            (string) $row['email'],
            (string) $row['password_hash'],
            new DateTimeImmutable((string) $row['created_at']),
        ) : null;
    }
}

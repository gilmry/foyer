<?php

declare(strict_types=1);

namespace TodoApp\Tests\Fakes;

use TodoApp\Domain\Account\Account;
use TodoApp\Domain\Account\AccountRepository;
use TodoApp\Domain\Account\EmailAlreadyUsedException;
use TodoApp\Domain\Account\PasswordHasher;
use TodoApp\Domain\Account\TokenGenerator;

/** Comptes, hacheur et tirage en mémoire pour les tests (aucune DB, rien d'aléatoire). */
final class FakeAccountStore implements AccountRepository, PasswordHasher, TokenGenerator
{
    /** @var array<string,Account> */
    public array $accounts = [];
    private int $seq = 0;

    public function findById(string $id): ?Account
    {
        return $this->accounts[$id] ?? null;
    }

    public function findByEmail(string $email): ?Account
    {
        foreach ($this->accounts as $account) {
            if ($account->email() === $email) {
                return $account;
            }
        }

        return null;
    }

    public function add(Account $account): void
    {
        if ($this->findByEmail($account->email()) !== null) {
            throw new EmailAlreadyUsedException();
        }
        $this->accounts[$account->id()] = $account;
    }

    public function hash(string $plainPassword): string
    {
        return 'hache:' . strrev($plainPassword);
    }

    public function verify(string $hash, string $plainPassword): bool
    {
        return $hash === $this->hash($plainPassword);
    }

    public function generate(): string
    {
        return 'secret-' . (++$this->seq);
    }
}

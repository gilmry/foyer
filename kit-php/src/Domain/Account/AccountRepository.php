<?php

declare(strict_types=1);

namespace TodoApp\Domain\Account;

/** Port de persistance des comptes. */
interface AccountRepository
{
    public function findById(string $id): ?Account;

    public function findByEmail(string $email): ?Account;

    /** @throws EmailAlreadyUsedException */
    public function add(Account $account): void;
}

<?php

declare(strict_types=1);

namespace TodoApp\Domain\Account;

/** Port de hachage des mots de passe. */
interface PasswordHasher
{
    public function hash(string $plainPassword): string;

    public function verify(string $hash, string $plainPassword): bool;
}

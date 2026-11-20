<?php

declare(strict_types=1);

namespace TodoApp\Domain\Account;

use DateTimeImmutable;

/** Compte — identifiant, courriel, et le HACHAGE du mot de passe (jamais le mot de passe). */
final class Account
{
    public function __construct(
        private readonly string $id,
        private readonly string $email,
        private readonly string $passwordHash,
        private readonly DateTimeImmutable $createdAt,
    ) {
    }

    public function id(): string
    {
        return $this->id;
    }

    public function email(): string
    {
        return $this->email;
    }

    public function passwordHash(): string
    {
        return $this->passwordHash;
    }

    public function createdAt(): DateTimeImmutable
    {
        return $this->createdAt;
    }

    /** @return array{id:string,email:string} vue publique : jamais le hachage */
    public function toView(): array
    {
        return ['id' => $this->id, 'email' => $this->email];
    }
}

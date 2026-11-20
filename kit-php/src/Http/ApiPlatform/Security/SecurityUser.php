<?php

declare(strict_types=1);

namespace TodoApp\Http\ApiPlatform\Security;

use Symfony\Component\Security\Core\User\PasswordAuthenticatedUserInterface;
use Symfony\Component\Security\Core\User\UserInterface;
use TodoApp\Domain\Account\Account;

/** Vue « sécurité Symfony » d'un compte. Vit dans l'adaptateur : le domaine ignore Symfony. */
final class SecurityUser implements UserInterface, PasswordAuthenticatedUserInterface
{
    public function __construct(
        public readonly string $id,
        public readonly string $email,
        private readonly string $passwordHash,
    ) {
    }

    public static function fromAccount(Account $account): self
    {
        return new self($account->id(), $account->email(), $account->passwordHash());
    }

    public function getUserIdentifier(): string
    {
        return $this->email;
    }

    public function getRoles(): array
    {
        return ['ROLE_USER'];
    }

    public function getPassword(): string
    {
        return $this->passwordHash;
    }

    public function eraseCredentials(): void
    {
    }
}

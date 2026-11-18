<?php

declare(strict_types=1);

namespace TodoApp\Http\ApiPlatform\Security;

use Symfony\Component\PasswordHasher\Hasher\PasswordHasherFactoryInterface;
use TodoApp\Domain\Account\PasswordHasher;

/** Port PasswordHasher servi par le hacheur `auto` de Symfony (celui que json_login vérifie). */
final class SymfonyPasswordHasher implements PasswordHasher
{
    public function __construct(private readonly PasswordHasherFactoryInterface $factory)
    {
    }

    public function hash(#[\SensitiveParameter] string $plainPassword): string
    {
        return $this->factory->getPasswordHasher(SecurityUser::class)->hash($plainPassword);
    }

    public function verify(string $hash, #[\SensitiveParameter] string $plainPassword): bool
    {
        return $this->factory->getPasswordHasher(SecurityUser::class)->verify($hash, $plainPassword);
    }
}

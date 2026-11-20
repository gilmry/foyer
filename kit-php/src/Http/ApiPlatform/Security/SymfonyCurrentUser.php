<?php

declare(strict_types=1);

namespace TodoApp\Http\ApiPlatform\Security;

use Symfony\Bundle\SecurityBundle\Security;
use TodoApp\Domain\Account\AuthenticationRequiredException;
use TodoApp\Domain\Account\CurrentUser;

/** Port CurrentUser servi par le composant de sécurité de Symfony (session ou jeton). */
final class SymfonyCurrentUser implements CurrentUser
{
    public function __construct(private readonly Security $security)
    {
    }

    public function id(): string
    {
        $user = $this->security->getUser();

        return $user instanceof SecurityUser ? $user->id : throw new AuthenticationRequiredException();
    }
}

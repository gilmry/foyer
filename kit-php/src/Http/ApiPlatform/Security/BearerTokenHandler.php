<?php

declare(strict_types=1);

namespace TodoApp\Http\ApiPlatform\Security;

use Symfony\Component\Security\Core\Exception\BadCredentialsException;
use Symfony\Component\Security\Http\AccessToken\AccessTokenHandlerInterface;
use Symfony\Component\Security\Http\Authenticator\Passport\Badge\UserBadge;
use TodoApp\Application\Account\ResolveAccessToken;

/** Vérifie un jeton porteur par le cas d'usage ResolveAccessToken (empreinte, échéance). */
final class BearerTokenHandler implements AccessTokenHandlerInterface
{
    public function __construct(
        private readonly ResolveAccessToken $resolve,
        private readonly AccountUserProvider $users,
    ) {
    }

    public function getUserBadgeFrom(#[\SensitiveParameter] string $accessToken): UserBadge
    {
        $accountId = $this->resolve->execute($accessToken);
        if ($accountId === null) {
            throw new BadCredentialsException();
        }

        return new UserBadge($accountId, $this->users->loadById(...));
    }
}

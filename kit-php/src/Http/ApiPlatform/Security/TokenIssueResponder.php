<?php

declare(strict_types=1);

namespace TodoApp\Http\ApiPlatform\Security;

use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\Security\Core\Authentication\Token\TokenInterface;
use Symfony\Component\Security\Http\Authentication\AuthenticationSuccessHandlerInterface;
use TodoApp\Application\Account\IssueAccessToken;

/** POST /api/tokens réussi : émet un jeton porteur, rendu en clair cette seule fois. */
final class TokenIssueResponder implements AuthenticationSuccessHandlerInterface
{
    public function __construct(private readonly IssueAccessToken $issue)
    {
    }

    public function onAuthenticationSuccess(Request $request, TokenInterface $token): Response
    {
        $user = $token->getUser();
        if (!$user instanceof SecurityUser) {
            return new JsonResponse(null, 500);
        }
        $issued = $this->issue->execute($user->id);

        return new JsonResponse(['token' => $issued['token'], 'expiresAt' => $issued['expiresAt']->format(DATE_ATOM)], 201);
    }
}

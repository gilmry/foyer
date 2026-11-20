<?php

declare(strict_types=1);

namespace TodoApp\Http\ApiPlatform\Security;

use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\Security\Core\Authentication\Token\TokenInterface;
use Symfony\Component\Security\Core\Exception\AccessDeniedException;
use Symfony\Component\Security\Core\Exception\AuthenticationException;
use Symfony\Component\Security\Core\Exception\TooManyLoginAttemptsAuthenticationException;
use Symfony\Component\Security\Http\Authentication\AuthenticationFailureHandlerInterface;
use Symfony\Component\Security\Http\Authentication\AuthenticationSuccessHandlerInterface;
use Symfony\Component\Security\Http\Authorization\AccessDeniedHandlerInterface;
use Symfony\Component\Security\Http\EntryPoint\AuthenticationEntryPointInterface;
use TodoApp\Http\ApiPlatform\ProblemSubscriber;

/**
 * Toutes les réponses d'authentification, en JSON :
 *  - connexion réussie → 200 et la vue du compte (le cookie de session part avec) ;
 *  - échec → 401, LE MÊME corps que le compte soit inconnu ou le mot de passe faux ;
 *  - trop d'essais → 429 ;
 *  - accès sans identité → 401 ; identité sans droit → 403.
 */
final class AuthenticationResponder implements AuthenticationSuccessHandlerInterface, AuthenticationFailureHandlerInterface, AuthenticationEntryPointInterface, AccessDeniedHandlerInterface
{
    public function onAuthenticationSuccess(Request $request, TokenInterface $token): Response
    {
        $user = $token->getUser();

        return new JsonResponse($user instanceof SecurityUser ? ['id' => $user->id, 'email' => $user->email] : [], 200);
    }

    public function onAuthenticationFailure(Request $request, AuthenticationException $exception): Response
    {
        if ($exception instanceof TooManyLoginAttemptsAuthenticationException) {
            return ProblemSubscriber::response(429, 'Trop de tentatives de connexion. Réessayez dans une minute.', [], ['Retry-After' => '60']);
        }

        return self::unauthorized();
    }

    public function start(Request $request, ?AuthenticationException $authException = null): Response
    {
        return self::unauthorized();
    }

    public function handle(Request $request, AccessDeniedException $accessDeniedException): Response
    {
        return ProblemSubscriber::response(403);
    }

    private static function unauthorized(): Response
    {
        return ProblemSubscriber::response(401, 'Authentification requise ou identifiants refusés.', [], ['WWW-Authenticate' => 'Bearer']);
    }
}

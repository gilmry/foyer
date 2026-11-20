<?php

declare(strict_types=1);

namespace TodoApp\Http\ApiPlatform;

use Symfony\Bundle\SecurityBundle\Security;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\HttpKernel\Exception\AccessDeniedHttpException;
use Symfony\Component\HttpKernel\Exception\BadRequestHttpException;
use Symfony\Component\HttpKernel\Exception\TooManyRequestsHttpException;
use TodoApp\Adapter\Services;
use TodoApp\Application\Account\RegisterAccount;
use TodoApp\Application\Account\RevokeAccessToken;
use TodoApp\Domain\Account\AuthenticationRequiredException;
use TodoApp\Domain\Account\EmailAlreadyUsedException;
use TodoApp\Http\ApiPlatform\Security\SecurityUser;

/** Routes de compte hors ressource API Platform : sonde, identité, inscription, révocation. */
final class AccountController
{
    public function __construct(private readonly Services $services)
    {
    }

    /** Sonde de santé publique : dit aussi QUELLE combinaison d'adaptateurs répond, et quelle version. */
    public function health(): JsonResponse
    {
        $config = $this->services->config();
        $this->services->pdo()->query('SELECT 1');

        return new JsonResponse([
            'status' => 'ok',
            'version' => $config['version'],
            'http' => 'apiplatform',
            'persistence' => $config['persistence'],
            'auth' => ['session', 'bearer'],
            'registration' => $config['registration'],
        ]);
    }

    public function me(Security $security): JsonResponse
    {
        $user = $security->getUser();
        if (!$user instanceof SecurityUser) {
            throw new AuthenticationRequiredException();
        }

        return new JsonResponse(['id' => $user->id, 'email' => $user->email]);
    }

    public const REGISTER_LIMIT = 10;
    public const REGISTER_WINDOW = 600;

    /**
     * Inscription, si la configuration l'ouvre (`registration: open`). Fermée : 403.
     * La réponse est LA MÊME (202, même corps, même calcul de hachage) que le courriel ait déjà un
     * compte ou non : la route ne permet pas de sonder les comptes existants. Dix demandes par
     * adresse IP et par dix minutes.
     */
    public function register(Request $request, RegisterAccount $register): JsonResponse
    {
        if ($this->services->config()['registration'] !== 'open') {
            throw new AccessDeniedHttpException('Inscription fermée.');
        }
        $slot = $this->services->attempts()->reserve('inscription:' . $request->getClientIp(), self::REGISTER_LIMIT, self::REGISTER_WINDOW);
        if (!$slot['accepted']) {
            throw new TooManyRequestsHttpException(max(1, $slot['retryAfter'] - time()));
        }
        $data = self::strictJson($request, ['email', 'password']);
        try {
            $register->execute($data['email'] ?? null, $data['password'] ?? null);
        } catch (EmailAlreadyUsedException) {
            // Même réponse : le compte existant n'est ni modifié ni révélé.
        }

        return new JsonResponse(['status' => 'accepted'], 202);
    }

    /** Révoque le jeton porteur de la requête. Avec une session et sans jeton : rien à révoquer. */
    public function revokeToken(Request $request, RevokeAccessToken $revoke): Response
    {
        if (!preg_match('/^Bearer\s+(\S+)$/i', (string) $request->headers->get('Authorization'), $m)) {
            throw new BadRequestHttpException('Aucun jeton porteur.');
        }
        $revoke->execute($m[1]);

        return new Response('', 204);
    }

    /** Atteint seulement quand la requête de connexion n'a pas la forme JSON attendue. */
    public function malformedLogin(): Response
    {
        throw new BadRequestHttpException('Corps JSON attendu.');
    }

    /**
     * @param list<string> $allowed
     * @return array<string,mixed>
     */
    private static function strictJson(Request $request, array $allowed): array
    {
        $data = json_decode($request->getContent(), true);
        if (!is_array($data) || ($data !== [] && array_is_list($data)) || array_diff(array_keys($data), $allowed) !== []) {
            throw new BadRequestHttpException('Corps de requête invalide ou champ inconnu.');
        }

        return $data;
    }
}

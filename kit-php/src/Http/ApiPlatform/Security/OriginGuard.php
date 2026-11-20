<?php

declare(strict_types=1);

namespace TodoApp\Http\ApiPlatform\Security;

use Symfony\Component\EventDispatcher\EventSubscriberInterface;
use Symfony\Component\HttpKernel\Event\RequestEvent;
use Symfony\Component\HttpKernel\KernelEvents;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\Security\Http\Event\LogoutEvent;
use TodoApp\Adapter\Services;
use TodoApp\Http\ApiPlatform\ProblemSubscriber;

/**
 * Protection CSRF d'une API JSON à cookie de session : contrôle de l'en-tête Origin.
 *
 * Toute requête non sûre (POST, PATCH, PUT, DELETE) de /api qui ne s'authentifie pas par jeton
 * doit porter une origine admise, sinon 403 — avant le pare-feu, donc avant toute connexion.
 * Origine admise : celle de l'adresse publique de la configuration ; sans adresse configurée
 * (harnais local), une origine du même hôte que la requête.
 * Exemptés : les requêtes à en-tête Authorization (aucun identifiant ambiant) et l'émission de
 * jeton (POST /api/tokens ne lit ni n'écrit de cookie).
 */
final class OriginGuard implements EventSubscriberInterface
{
    public function __construct(private readonly Services $services)
    {
    }

    public static function getSubscribedEvents(): array
    {
        return [
            // Avant le pare-feu (priorité 8).
            KernelEvents::REQUEST => ['onRequest', 16],
            LogoutEvent::class => 'onLogout',
        ];
    }

    public function onRequest(RequestEvent $event): void
    {
        $request = $event->getRequest();
        if (!$event->isMainRequest() || !str_starts_with($request->getPathInfo(), '/api')) {
            return;
        }
        // Une API n'est jamais la « page à retrouver après connexion » : sans cette marque, le
        // pare-feu à session ouvrirait une session (et poserait un cookie) rien que pour mémoriser
        // l'adresse d'une requête refusée.
        $request->headers->set('X-Requested-With', 'XMLHttpRequest');
        if ($request->isMethodSafe()) {
            return;
        }
        if (BearerRequestMatcher::carriesAuthorization($request) || $request->getPathInfo() === '/api/tokens') {
            return;
        }

        $origin = rtrim((string) $request->headers->get('Origin'), '/');
        $publicUrl = (string) $this->services->config()['public_url'];
        if ($publicUrl !== '') {
            $allowed = self::origin($publicUrl) !== null && $origin === self::origin($publicUrl);
        } else {
            $allowed = $origin !== '' && parse_url($origin, PHP_URL_HOST) !== null
                && self::hostPort($origin) === strtolower((string) $request->headers->get('Host'));
        }
        if (!$allowed) {
            $event->setResponse(ProblemSubscriber::response(403, 'Origine de la requête refusée.'));
        }
    }

    /** Déconnexion : 204 sans corps, au lieu de la redirection par défaut. */
    public function onLogout(LogoutEvent $event): void
    {
        $event->setResponse(new Response('', 204));
    }

    private static function origin(string $url): ?string
    {
        $p = parse_url($url);
        if (!isset($p['scheme'], $p['host'])) {
            return null;
        }

        return strtolower($p['scheme'] . '://' . $p['host']) . (isset($p['port']) ? ':' . $p['port'] : '');
    }

    private static function hostPort(string $url): string
    {
        $p = parse_url($url);

        return strtolower((string) ($p['host'] ?? '')) . (isset($p['port']) ? ':' . $p['port'] : '');
    }
}

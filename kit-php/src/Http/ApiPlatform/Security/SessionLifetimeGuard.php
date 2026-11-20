<?php

declare(strict_types=1);

namespace TodoApp\Http\ApiPlatform\Security;

use Symfony\Component\EventDispatcher\EventSubscriberInterface;
use Symfony\Component\HttpKernel\Event\RequestEvent;
use Symfony\Component\HttpKernel\KernelEvents;
use TodoApp\Adapter\Services;

/**
 * Expiration des sessions CÔTÉ APPLICATION, contrôlée à chaque requête : une session inactive
 * depuis `session_idle` secondes, ou ouverte depuis `session_max` secondes, est détruite avant que
 * le pare-feu la lise. On ne s'en remet pas à la purge des fichiers de session par PHP, qui est
 * probabiliste et que certains hébergeurs désactivent : sans ce contrôle, une session volée
 * vivrait tant que son fichier existe.
 */
final class SessionLifetimeGuard implements EventSubscriberInterface
{
    public function __construct(private readonly Services $services)
    {
    }

    public static function getSubscribedEvents(): array
    {
        // Après l'écouteur de session (128), avant le pare-feu (8).
        return [KernelEvents::REQUEST => ['onRequest', 12]];
    }

    public function onRequest(RequestEvent $event): void
    {
        $request = $event->getRequest();
        if (!$event->isMainRequest() || !$request->hasPreviousSession()) {
            return;
        }
        $config = $this->services->config();
        $session = $request->getSession();
        $session->start();
        $meta = $session->getMetadataBag();
        $now = time();
        if ($now - $meta->getLastUsed() > (int) $config['session_idle'] || $now - $meta->getCreated() > (int) $config['session_max']) {
            $session->invalidate();
        }
    }
}

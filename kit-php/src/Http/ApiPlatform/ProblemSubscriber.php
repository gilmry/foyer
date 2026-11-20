<?php

declare(strict_types=1);

namespace TodoApp\Http\ApiPlatform;

use Psr\Log\LoggerInterface;
use Symfony\Component\EventDispatcher\EventSubscriberInterface;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpKernel\Event\ExceptionEvent;
use Symfony\Component\HttpKernel\Event\ResponseEvent;
use Symfony\Component\HttpKernel\Exception\HttpExceptionInterface;
use Symfony\Component\HttpKernel\KernelEvents;
use Symfony\Component\Security\Core\Exception\AccessDeniedException;
use Symfony\Component\Security\Core\Exception\AuthenticationException;
use Symfony\Component\Serializer\Exception\ExceptionInterface as SerializerException;
use Symfony\Component\Validator\ConstraintViolationListInterface;
use TodoApp\Domain\Account\AccountValidationException;
use TodoApp\Domain\Account\AuthenticationRequiredException;
use TodoApp\Domain\Account\EmailAlreadyUsedException;
use TodoApp\Domain\Todo\TodoNotFoundException;
use TodoApp\Domain\Todo\TodoValidationException;
use TodoApp\Http\Problem;

/**
 * Toute erreur de /api sort au format problème (RFC 9457), sans trace ni message interne.
 * C'est la SEULE traduction des exceptions (du domaine, d'API Platform, de Symfony) en codes
 * HTTP : le domaine ignore HTTP. Le détail d'une erreur 5xx va au journal, jamais dans la réponse.
 */
final class ProblemSubscriber implements EventSubscriberInterface
{
    public function __construct(private readonly LoggerInterface $logger)
    {
    }

    public static function getSubscribedEvents(): array
    {
        return [
            KernelEvents::EXCEPTION => [
                // Une panne de base est traitée AVANT tout le monde (pare-feu, journal de Symfony) :
                // le message de PDO nomme l'hôte et l'identifiant, il ne doit pas atteindre le journal.
                ['onDatabaseFailure', 4],
                // Le reste : après l'écouteur du pare-feu (priorité 1), qui garde 401 et 403.
                ['onException', 0],
            ],
            KernelEvents::RESPONSE => ['onResponse', -10],
        ];
    }

    public function onDatabaseFailure(ExceptionEvent $event): void
    {
        if (Problem::isDatabaseFailure($event->getThrowable())) {
            $this->onException($event);
        }
    }

    public function onException(ExceptionEvent $event): void
    {
        $e = $event->getThrowable();
        [$status, $detail, $violations] = $this->translate($e);
        if ($status >= 500) {
            // La classe et, pour la base, le seul code SQLSTATE : un message PDO porte l'hôte et l'identifiant.
            $this->logger->error('Erreur {status} : {class}', [
                'status' => $status,
                'class' => $e::class,
                'sqlstate' => $e instanceof \PDOException ? $e->getCode() : null,
            ]);
        }
        $headers = $status === 401 ? ['WWW-Authenticate' => 'Bearer'] : [];
        if ($e instanceof HttpExceptionInterface && $status === 429) {
            $headers += array_intersect_key($e->getHeaders(), ['Retry-After' => true]);
        }
        $event->setResponse(self::response($status, $detail, $violations, $headers));
    }

    /** Les réponses de l'API ne se mettent pas en cache. (Les en-têtes de sécurité sont posés par Front.) */
    public function onResponse(ResponseEvent $event): void
    {
        $event->getResponse()->headers->set('Cache-Control', 'no-store');
    }

    /**
     * @param list<array{propertyPath:string,message:string}> $violations
     * @param array<string,string> $headers
     */
    public static function response(int $status, ?string $detail = null, array $violations = [], array $headers = []): JsonResponse
    {
        $response = new JsonResponse(Problem::body($status, $detail, $violations), $status, $headers);
        $response->setEncodingOptions(JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
        $response->headers->set('Content-Type', Problem::CONTENT_TYPE);

        return $response;
    }

    /** @return array{0:int,1:?string,2:list<array{propertyPath:string,message:string}>} */
    private function translate(\Throwable $e): array
    {
        if (Problem::isDatabaseFailure($e)) {
            return [503, null, []];
        }
        if (method_exists($e, 'getConstraintViolationList') && $e->getConstraintViolationList() instanceof ConstraintViolationListInterface) {
            $violations = [];
            foreach ($e->getConstraintViolationList() as $v) {
                $violations[] = ['propertyPath' => (string) $v->getPropertyPath(), 'message' => (string) $v->getMessage()];
            }

            return [422, null, $violations];
        }

        return match (true) {
            $e instanceof TodoValidationException => [422, null, array_map(
                static fn (string $m): array => ['propertyPath' => 'title', 'message' => $m],
                $e->errors(),
            )],
            $e instanceof AccountValidationException => [422, null, array_map(
                static fn (string $field, string $m): array => ['propertyPath' => $field, 'message' => $m],
                array_keys($e->errors()),
                array_values($e->errors()),
            )],
            $e instanceof TodoNotFoundException => [404, 'Ressource introuvable.', []],
            $e instanceof EmailAlreadyUsedException => [409, $e->getMessage(), []],
            $e instanceof AuthenticationRequiredException, $e instanceof AuthenticationException => [401, 'Authentification requise.', []],
            $e instanceof AccessDeniedException => [403, null, []],
            $e instanceof SerializerException => [400, 'Corps de requête invalide ou champ inconnu.', []],
            $e instanceof HttpExceptionInterface => self::http($e),
            default => [500, null, []],
        };
    }

    /** @return array{0:int,1:?string,2:list<array{propertyPath:string,message:string}>} */
    private static function http(HttpExceptionInterface $e): array
    {
        $status = $e->getStatusCode();
        if ($status >= 500) {
            return [$status === 503 ? 503 : 500, null, []];
        }
        // Les messages d'API Platform et de Symfony peuvent nommer des classes : on n'en garde aucun.
        $detail = match ($status) {
            400 => 'Corps de requête invalide ou champ inconnu.',
            404 => 'Ressource introuvable.',
            default => null,
        };

        return [$status, $detail, []];
    }
}

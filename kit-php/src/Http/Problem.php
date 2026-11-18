<?php

declare(strict_types=1);

namespace TodoApp\Http;

/**
 * Corps d'erreur au format problème (RFC 9457, application/problem+json), commun aux deux
 * adaptateurs HTTP. Jamais de trace, de nom de classe ni de message interne.
 */
final class Problem
{
    public const CONTENT_TYPE = 'application/problem+json; charset=utf-8';

    private const TITLES = [
        400 => 'Requête invalide',
        401 => 'Authentification requise',
        403 => 'Accès refusé',
        404 => 'Introuvable',
        405 => 'Méthode non permise',
        406 => 'Format non disponible',
        409 => 'Conflit',
        415 => 'Format non pris en charge',
        422 => 'Validation refusée',
        429 => 'Trop de tentatives',
        500 => 'Erreur interne',
        503 => 'Service temporairement indisponible',
    ];

    /**
     * @param list<array{propertyPath:string,message:string}> $violations
     * @return array<string,mixed>
     */
    public static function body(int $status, ?string $detail = null, array $violations = []): array
    {
        $body = [
            'type' => 'about:blank',
            'title' => self::TITLES[$status] ?? 'Erreur',
            'status' => $status,
        ];
        if ($detail !== null && $detail !== '') {
            $body['detail'] = $detail;
        }
        if ($violations !== []) {
            $body['violations'] = $violations;
        }

        return $body;
    }

    /** @param array<string,mixed> $body */
    public static function encode(array $body): string
    {
        return (string) json_encode($body, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    }

    /** Une base injoignable n'est pas une erreur du client : 503, sans rien dire de la base. */
    public static function isDatabaseFailure(?\Throwable $e): bool
    {
        for (; $e !== null; $e = $e->getPrevious()) {
            if ($e instanceof \PDOException || is_a($e, 'Doctrine\DBAL\Exception')) {
                return true;
            }
        }

        return false;
    }
}

<?php

declare(strict_types=1);

namespace TodoApp\Http;

/**
 * En-têtes de sécurité posés par l'APPLICATION, pour ne pas dépendre des réglages de l'hébergeur.
 * HSTS n'est émis que si l'adresse publique configurée est en https (un navigateur l'ignore en http).
 */
final class SecurityHeaders
{
    /** @return array<string,string> */
    public static function all(bool $https): array
    {
        $headers = [
            'X-Content-Type-Options' => 'nosniff',
            'X-Frame-Options' => 'DENY',
            // Tout vient du site lui-même ; aucun script en ligne, aucun greffon, aucune inclusion en cadre.
            'Content-Security-Policy' => "default-src 'self'; script-src 'self'; object-src 'none'; base-uri 'none'; form-action 'self'; frame-ancestors 'none'",
            'Referrer-Policy' => 'no-referrer',
        ];
        if ($https) {
            $headers['Strict-Transport-Security'] = 'max-age=31536000';
        }

        return $headers;
    }

    public static function emit(bool $https): void
    {
        foreach (self::all($https) as $name => $value) {
            header($name . ': ' . $value);
        }
        header_remove('X-Powered-By');
    }
}

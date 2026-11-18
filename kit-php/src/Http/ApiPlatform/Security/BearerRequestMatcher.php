<?php

declare(strict_types=1);

namespace TodoApp\Http\ApiPlatform\Security;

use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\RequestMatcherInterface;

/** Une requête /api qui porte un en-tête Authorization relève du pare-feu à jeton, sans état. */
final class BearerRequestMatcher implements RequestMatcherInterface
{
    public function matches(Request $request): bool
    {
        return str_starts_with($request->getPathInfo(), '/api') && self::carriesAuthorization($request);
    }

    public static function carriesAuthorization(Request $request): bool
    {
        return trim((string) $request->headers->get('Authorization')) !== '';
    }
}

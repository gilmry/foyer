<?php

declare(strict_types=1);

namespace TodoApp\Http;

/** Réponses HTTP de l'adaptateur vanilla. */
final class Response
{
    /** @param mixed $data */
    public static function json($data, int $status = 200): void
    {
        http_response_code($status);
        header('Content-Type: application/json; charset=utf-8');
        header('Cache-Control: no-store');
        echo json_encode($data, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    }

    public static function noContent(): void
    {
        http_response_code(204);
        header('Cache-Control: no-store');
    }

    /** @param list<array{propertyPath:string,message:string}> $violations */
    public static function problem(int $status, ?string $detail = null, array $violations = []): void
    {
        http_response_code($status);
        header('Content-Type: ' . Problem::CONTENT_TYPE);
        header('Cache-Control: no-store');
        if ($status === 401) {
            header('WWW-Authenticate: Bearer');
        }
        echo Problem::encode(Problem::body($status, $detail, $violations));
    }
}

<?php

declare(strict_types=1);

namespace TodoApp\Http;

/** Requête HTTP minimale : méthode, chemin, corps JSON. */
final class Request
{
    public function __construct(
        private readonly string $method,
        private readonly string $path,
        private readonly string $rawBody,
    ) {
    }

    public static function fromGlobals(): self
    {
        $method = $_SERVER['REQUEST_METHOD'] ?? 'GET';
        $uri = $_SERVER['REQUEST_URI'] ?? '/';
        $path = parse_url($uri, PHP_URL_PATH) ?: '/';

        return new self($method, $path, file_get_contents('php://input') ?: '');
    }

    public function method(): string
    {
        return $this->method;
    }

    public function path(): string
    {
        return $this->path;
    }

    /**
     * Corps JSON décodé. Désérialisation stricte : un JSON invalide donne un tableau vide,
     * la validation du domaine rejette ensuite les champs manquants.
     *
     * @return array<string,mixed>
     */
    public function json(): array
    {
        if (trim($this->rawBody) === '') {
            return [];
        }
        $data = json_decode($this->rawBody, true);

        return is_array($data) ? $data : [];
    }
}

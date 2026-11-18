<?php

declare(strict_types=1);

namespace TodoApp\Http;

/** Requête HTTP minimale de l'adaptateur vanilla : méthode, chemin, corps JSON, jeton porteur. */
final class Request
{
    /** @param array<string,string> $query */
    public function __construct(
        private readonly string $method,
        private readonly string $path,
        private readonly string $rawBody,
        private readonly ?string $authorization = null,
        private readonly array $query = [],
    ) {
    }

    public static function fromGlobals(): self
    {
        $method = $_SERVER['REQUEST_METHOD'] ?? 'GET';
        $uri = $_SERVER['REQUEST_URI'] ?? '/';
        $path = parse_url($uri, PHP_URL_PATH) ?: '/';
        // En FastCGI, l'en-tête arrive par la réécriture de public/.htaccess (parfois préfixé REDIRECT_).
        $authorization = $_SERVER['HTTP_AUTHORIZATION'] ?? $_SERVER['REDIRECT_HTTP_AUTHORIZATION'] ?? null;
        parse_str((string) parse_url($uri, PHP_URL_QUERY), $query);

        return new self($method, $path, file_get_contents('php://input') ?: '', $authorization, array_filter($query, 'is_string'));
    }

    public function method(): string
    {
        return $this->method;
    }

    public function path(): string
    {
        return $this->path;
    }

    public function queryInt(string $name, int $default): int
    {
        $value = $this->query[$name] ?? null;

        return $value !== null && preg_match('/^\d{1,9}$/', $value) ? (int) $value : $default;
    }

    /** Jeton porteur de l'en-tête Authorization, ou null. */
    public function bearerToken(): ?string
    {
        if ($this->authorization !== null && preg_match('/^Bearer\s+([A-Za-z0-9._~+\/=-]+)$/i', trim($this->authorization), $m)) {
            return $m[1];
        }

        return null;
    }

    /**
     * Corps JSON décodé — désérialisation STRICTE : le corps doit être un objet JSON et ne porter
     * que les champs attendus. Un champ inconnu (dont un champ propriétaire) est refusé.
     *
     * @param list<string> $allowed
     * @return array<string,mixed>
     * @throws MalformedRequestException
     */
    public function json(array $allowed): array
    {
        if (trim($this->rawBody) === '') {
            throw new MalformedRequestException('Corps JSON attendu.');
        }
        $data = json_decode($this->rawBody, true);
        if (!is_array($data) || ($data !== [] && array_is_list($data))) {
            throw new MalformedRequestException('Le corps doit être un objet JSON.');
        }
        $unknown = array_diff(array_keys($data), $allowed);
        if ($unknown !== []) {
            throw new MalformedRequestException('Champ inconnu dans la requête.');
        }

        return $data;
    }
}

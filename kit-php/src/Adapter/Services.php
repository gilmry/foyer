<?php

declare(strict_types=1);

namespace TodoApp\Adapter;

use PDO;
use TodoApp\Adapter\Account\NativePasswordHasher;
use TodoApp\Adapter\Account\PdoAccessTokenRepository;
use TodoApp\Adapter\Account\PdoAccountRepository;
use TodoApp\Adapter\Account\PdoAttemptLimiter;
use TodoApp\Adapter\Account\RandomTokenGenerator;
use TodoApp\Adapter\Todo\RealClock;
use TodoApp\Adapter\Todo\RepositoryFactory;
use TodoApp\Adapter\Todo\UuidGenerator;
use TodoApp\Database;
use TodoApp\Domain\Account\AccessTokenRepository;
use TodoApp\Domain\Account\AccountRepository;
use TodoApp\Domain\Account\PasswordHasher;
use TodoApp\Domain\Account\TokenGenerator;
use TodoApp\Domain\Todo\Clock;
use TodoApp\Domain\Todo\IdGenerator;
use TodoApp\Domain\Todo\TodoRepository;

/**
 * Racine de composition des adaptateurs : la MÊME pour l'adaptateur vanilla, l'adaptateur
 * API Platform et les outils bin/. Connexion ouverte au premier besoin seulement.
 */
final class Services
{
    private ?PDO $pdo = null;
    private ?TodoRepository $todos = null;

    /** @param array<string,mixed> $config */
    public function __construct(private readonly array $config)
    {
    }

    /** @return array<string,mixed> */
    public function config(): array
    {
        return $this->config;
    }

    public function pdo(): PDO
    {
        return $this->pdo ??= Database::connect($this->config);
    }

    public function todos(): TodoRepository
    {
        return $this->todos ??= RepositoryFactory::make($this->config, $this->pdo());
    }

    public function accounts(): AccountRepository
    {
        return new PdoAccountRepository($this->pdo());
    }

    public function tokens(): AccessTokenRepository
    {
        return new PdoAccessTokenRepository($this->pdo());
    }

    /** Compteurs d'essais (connexion, inscription) : en base, sous verrou de la base. */
    public function attempts(): PdoAttemptLimiter
    {
        return new PdoAttemptLimiter($this->pdo());
    }

    public function hasher(): PasswordHasher
    {
        return new NativePasswordHasher();
    }

    public function tokenGenerator(): TokenGenerator
    {
        return new RandomTokenGenerator();
    }

    public function clock(): Clock
    {
        return new RealClock();
    }

    public function ids(): IdGenerator
    {
        return new UuidGenerator();
    }
}

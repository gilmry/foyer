<?php

declare(strict_types=1);

namespace TodoApp\Http\ApiPlatform;

use TodoApp\Adapter\Todo\RepositoryFactory;
use TodoApp\Database;
use TodoApp\Domain\Todo\TodoRepository;

/** Construit le repo (CQRS ou Doctrine selon TODO_PERSISTENCE) depuis l'environnement. */
final class RepoBuilder
{
    public static function make(): TodoRepository
    {
        $config = ['db' => [
            'host' => getenv('DB_HOST') ?: 'localhost',
            'port' => (int) (getenv('DB_PORT') ?: 3306),
            'database' => getenv('DB_NAME') ?: 'todo',
            'username' => getenv('DB_USER') ?: 'root',
            'password' => getenv('DB_PASSWORD') ?: '',
            'charset' => 'utf8mb4',
        ]];

        return RepositoryFactory::make($config, Database::connect($config));
    }
}

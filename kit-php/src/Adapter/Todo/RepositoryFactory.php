<?php

declare(strict_types=1);

namespace TodoApp\Adapter\Todo;

use TodoApp\Adapter\Todo\Doctrine\EntityManagerFactory;
use TodoApp\Domain\Todo\TodoRepository;

/**
 * Sélection de l'adaptateur de persistance — CQRS (SQL pur) ou Doctrine (ORM).
 * Piloté par TODO_PERSISTENCE : `cqrs` (défaut, aucun vendor requis) ou `doctrine`
 * (charge l'autoloader Composer). Même port TodoRepository → interchangeable sans toucher au
 * domaine ni à l'application. Choix = point d'ADR (bmad/archetypes.md), pas une question au PO.
 */
final class RepositoryFactory
{
    /** @param array<string,mixed> $config */
    public static function make(array $config, \PDO $db): TodoRepository
    {
        $kind = getenv('TODO_PERSISTENCE') ?: 'cqrs';

        if ($kind === 'doctrine') {
            $autoload = dirname(__DIR__, 3) . '/vendor/autoload.php';
            if (is_file($autoload)) {
                require_once $autoload;
            }
            return new DoctrineTodoRepository(EntityManagerFactory::create($config));
        }

        return new CqrsTodoRepository($db);
    }
}

<?php

declare(strict_types=1);

namespace TodoApp\Adapter\Todo\Doctrine;

use Doctrine\DBAL\DriverManager;
use Doctrine\ORM\EntityManager;
use Doctrine\ORM\ORMSetup;

/** Construit l'EntityManager Doctrine depuis la config (mapping par attributs de cet adaptateur). */
final class EntityManagerFactory
{
    /** @param array<string,mixed> $config */
    public static function create(array $config): EntityManager
    {
        $ormConfig = ORMSetup::createAttributeMetadataConfiguration(
            paths: [__DIR__],   // TodoRecord et ses attributs vivent ici
            isDevMode: true,
        );

        $db = $config['db'] ?? [];
        $connection = DriverManager::getConnection([
            'driver' => 'pdo_mysql',
            'host' => $db['host'] ?? 'localhost',
            'port' => (int) ($db['port'] ?? 3306),
            'dbname' => $db['database'] ?? '',
            'user' => $db['username'] ?? '',
            'password' => $db['password'] ?? '',
            'charset' => $db['charset'] ?? 'utf8mb4',
        ], $ormConfig);

        return new EntityManager($connection, $ormConfig);
    }
}

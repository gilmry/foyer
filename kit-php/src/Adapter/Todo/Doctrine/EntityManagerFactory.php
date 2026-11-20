<?php

declare(strict_types=1);

namespace TodoApp\Adapter\Todo\Doctrine;

use Doctrine\DBAL\DriverManager;
use Doctrine\ORM\EntityManager;
use Doctrine\ORM\ORMSetup;
use Symfony\Component\Cache\Adapter\FilesystemAdapter;

/** Construit l'EntityManager Doctrine depuis la config (mapping par attributs de cet adaptateur). */
final class EntityManagerFactory
{
    /** @param array<string,mixed> $config */
    public static function create(array $config): EntityManager
    {
        // État de Doctrine dans var/ de l'instance, pas dans le répertoire temporaire du système.
        $varDir = ($config['var_dir'] ?? dirname(__DIR__, 4) . '/var') . '/doctrine';
        // Version déployée (sous versions/<nom>) : mode production — métadonnées en cache, rangées
        // par version puisqu'elles dérivent du code. En local : mode développement, rien en cache.
        $version = (string) ($config['version'] ?? 'dev');
        $production = $version !== 'dev';
        $ormConfig = ORMSetup::createAttributeMetadataConfiguration(
            paths: [__DIR__],   // TodoRecord et ses attributs vivent ici
            isDevMode: !$production,
            proxyDir: $varDir . '/proxies',
            cache: $production ? new FilesystemAdapter('orm', 0, $varDir . '/' . preg_replace('/[^A-Za-z0-9_-]/', '', $version)) : null,
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

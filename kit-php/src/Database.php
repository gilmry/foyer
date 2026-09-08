<?php

declare(strict_types=1);

namespace TodoApp;

use PDO;

/** Fabrique de connexion PDO/MySQL. */
final class Database
{
    /** @param array<string,mixed> $config */
    public static function connect(array $config): PDO
    {
        $db = $config['db'] ?? [];
        $dsn = sprintf(
            'mysql:host=%s;port=%d;dbname=%s;charset=%s',
            $db['host'] ?? 'localhost',
            (int) ($db['port'] ?? 3306),
            $db['database'] ?? '',
            $db['charset'] ?? 'utf8mb4',
        );

        return new PDO($dsn, $db['username'] ?? '', $db['password'] ?? '', [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
            PDO::ATTR_EMULATE_PREPARES => false,
        ]);
    }
}

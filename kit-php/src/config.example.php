<?php

declare(strict_types=1);

/**
 * Gabarit de configuration. Copier en `config.php` (hors dépôt, cf. .gitignore) et
 * renseigner les identifiants réels. Aucun secret réel ne doit figurer ici (gate plancher G1).
 */
return [
    'db' => [
        'host' => getenv('DB_HOST') ?: 'localhost',
        'port' => (int) (getenv('DB_PORT') ?: 3306),
        'database' => getenv('DB_NAME') ?: 'todo',
        'username' => getenv('DB_USER') ?: 'todo',
        'password' => getenv('DB_PASSWORD') ?: '',
        'charset' => 'utf8mb4',
    ],
];

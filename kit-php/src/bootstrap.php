<?php

declare(strict_types=1);

/**
 * Autoloader PSR-4 minimal (l'adaptateur vanilla et les outils bin/ n'ont pas besoin de Composer).
 * Mappe le préfixe TodoApp\ vers src/.
 */
spl_autoload_register(static function (string $class): void {
    $prefix = 'TodoApp\\';
    if (strncmp($class, $prefix, strlen($prefix)) !== 0) {
        return;
    }
    $relative = substr($class, strlen($prefix));
    $path = __DIR__ . '/' . str_replace('\\', '/', $relative) . '.php';
    if (is_file($path)) {
        require $path;
    }
});

// Les dates sont stockées sans fuseau : on les écrit et on les relit en UTC, quel que soit le
// fuseau par défaut du PHP de l'hébergeur.
date_default_timezone_set('UTC');

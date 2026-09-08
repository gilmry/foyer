<?php

declare(strict_types=1);

/**
 * Autoloader PSR-4 minimal (le kit vanilla n'a pas de vendor/composer).
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

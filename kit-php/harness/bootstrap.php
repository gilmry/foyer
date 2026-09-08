<?php

declare(strict_types=1);

/** Autoloader de test : mappe TodoApp\ → src/ et TodoApp\Tests\ → tests/. */
spl_autoload_register(static function (string $class): void {
    $root = dirname(__DIR__);
    $map = [
        'TodoApp\\Tests\\' => $root . '/tests/',
        'TodoApp\\' => $root . '/src/',
    ];
    foreach ($map as $prefix => $base) {
        if (strncmp($class, $prefix, strlen($prefix)) === 0) {
            $relative = substr($class, strlen($prefix));
            $path = $base . str_replace('\\', '/', $relative) . '.php';
            if (is_file($path)) {
                require $path;
            }
            return;
        }
    }
});

<?php

declare(strict_types=1);

/**
 * Routeur pour le serveur PHP intégré (php -S … -t public harness/dev-router.php).
 * Sert les fichiers statiques de public/ ; route tout /api/* vers api/index.php.
 */
$uri = parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH) ?: '/';

if (str_starts_with($uri, '/api/')) {
    require __DIR__ . '/../api/index.php';
    return true;
}

$file = __DIR__ . '/../public' . ($uri === '/' ? '/index.html' : $uri);
if (is_file($file)) {
    return false; // laisse le serveur intégré servir le fichier
}

http_response_code(404);
echo 'Not found';
return true;

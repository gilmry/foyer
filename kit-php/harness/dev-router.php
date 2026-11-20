<?php

declare(strict_types=1);

/**
 * Routeur pour le serveur PHP intégré (php -S … -t public harness/dev-router.php) — harnais local
 * seulement. Il imite public/.htaccess : les fichiers statiques de public/ sont servis tels quels,
 * les fichiers cachés sont refusés, tout le reste passe par le MÊME contrôleur frontal
 * (public/index.php) que sur l'hébergeur.
 */
$uri = parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH) ?: '/';

if (preg_match('#(^|/)\.(?!well-known/)#', $uri)) {
    http_response_code(403);
    echo 'Interdit.';
    return true;
}

$file = __DIR__ . '/../public' . $uri;
if ($uri !== '/' && $uri !== '/index.html' && $uri !== '/index.php' && is_file($file)) {
    // Le serveur intégré n'a pas mod_headers : on sert le fichier ici, avec les mêmes en-têtes
    // que ceux que public/.htaccess pose sur les fichiers statiques.
    $types = ['js' => 'application/javascript', 'css' => 'text/css', 'json' => 'application/json', 'svg' => 'image/svg+xml',
        'png' => 'image/png', 'ico' => 'image/x-icon', 'html' => 'text/html; charset=utf-8', 'map' => 'application/json', 'txt' => 'text/plain; charset=utf-8'];
    header('Content-Type: ' . ($types[strtolower(pathinfo($file, PATHINFO_EXTENSION))] ?? 'application/octet-stream'));
    header('X-Content-Type-Options: nosniff');
    header('X-Frame-Options: DENY');
    header('Referrer-Policy: no-referrer');
    readfile($file);
    return true;
}

require __DIR__ . '/../public/index.php';
return true;

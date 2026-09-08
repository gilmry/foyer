<?php

declare(strict_types=1);

use TodoApp\Application;

// Adaptateur HTTP au choix : `vanilla` (routeur maison, défaut) ou `apiplatform` (Symfony/API Platform).
if ((getenv('TODO_HTTP') ?: 'vanilla') === 'apiplatform') {
    require __DIR__ . '/apiplatform.php';
    return;
}

try {
    require __DIR__ . '/../src/bootstrap.php';
    $configFile = is_file(__DIR__ . '/../src/config.php')
        ? __DIR__ . '/../src/config.php'
        : __DIR__ . '/../src/config.example.php';
    $config = require $configFile;
    (new Application($config))->handle();
} catch (Throwable) {
    http_response_code(503);
    header('Content-Type: application/json; charset=utf-8');
    echo json_encode(['error' => 'Service temporairement indisponible.']);
}

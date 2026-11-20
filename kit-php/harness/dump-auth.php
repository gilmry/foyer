<?php

declare(strict_types=1);

/**
 * Harnais : vide les tables `accounts` et `access_tokens` sur la sortie standard et compte les
 * lignes qui ne sont PAS un hachage (bcrypt ou argon2 pour un mot de passe, SHA-256 pour un jeton).
 * Sert aux gates à prouver qu'aucun mot de passe ni jeton n'est stocké en clair.
 * Avec l'argument `todos` : rend seulement le nombre de lignes de la table todos.
 */
require __DIR__ . '/../src/bootstrap.php';

$db = TodoApp\Database::connect(TodoApp\Config::load());
if (($argv[1] ?? '') === 'todos') {
    echo 'TODOS=', (int) $db->query('SELECT COUNT(*) FROM todos')->fetchColumn(), "\n";
    exit(0);
}
$offFormat = 0;
foreach ($db->query('SELECT * FROM accounts')->fetchAll() as $row) {
    echo json_encode($row), "\n";
    $offFormat += preg_match('/^\$(2y|argon2id?)\$/', (string) $row['password_hash']) ? 0 : 1;
}
foreach ($db->query('SELECT * FROM access_tokens')->fetchAll() as $row) {
    echo json_encode($row), "\n";
    $offFormat += preg_match('/^[0-9a-f]{64}$/', (string) $row['token_hash']) ? 0 : 1;
}
echo 'HORS_FORMAT=', $offFormat, "\n";

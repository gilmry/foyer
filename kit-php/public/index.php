<?php

declare(strict_types=1);

/**
 * Contrôleur frontal — le SEUL fichier PHP servi. La racine du site pointe sur public/ : rien
 * d'autre du kit (src/, vendor/, database/, la configuration) n'est joignable par HTTP.
 * Toute la logique est dans src/Http/Front.php.
 *
 * Ce fichier ne fait qu'une chose : trouver la racine de la VERSION SERVIE. Sur un hébergeur, la
 * racine du site passe par le lien `courant` (…/<instance>/courant/public). PHP garde en mémoire
 * la résolution des chemins (cache realpath, 120 s par défaut) et le code compilé (OPcache) : sans
 * précaution, un processus continue de servir l'ancienne version jusqu'à deux minutes après la
 * bascule du lien, pendant qu'un autre sert déjà la nouvelle. On lit donc le lien à chaque requête
 * (readlink n'est pas mis en cache) et l'on charge le code par son chemin réel : la bascule est
 * vue par tous les processus à la requête suivante. Ce fichier reste identique d'une version à
 * l'autre, peu importe donc laquelle de ses copies s'exécute.
 */
$root = dirname(__DIR__);
$link = dirname((string) ($_SERVER['SCRIPT_FILENAME'] ?? ''), 2);
if ($link !== '' && $link !== '.' && is_link($link)) {
    $target = (string) readlink($link);
    $candidate = str_starts_with($target, '/') ? $target : dirname($link) . '/' . $target;
    if (is_file($candidate . '/src/bootstrap.php')) {
        $root = $candidate;
    }
}

require $root . '/src/bootstrap.php';

TodoApp\Http\Front::run($root);

<?php

declare(strict_types=1);

/**
 * Gabarit de configuration. Copier en `config.php` (hors dépôt, cf. .gitignore), droits 600, et
 * renseigner les valeurs réelles. Aucun secret réel ne doit figurer ici (gate plancher G1).
 * Sur un hébergeur, ce fichier est écrit UNE fois par deploiement/alwaysdata/deployer.sh, sur le
 * serveur ; `src/config.php` de chaque version est un lien vers lui.
 * Les variables d'environnement (TODO_HTTP, TODO_PERSISTENCE, DB_*, KIT_*) restent prioritaires :
 * voir src/Config.php.
 */
return [
    // Adaptateur HTTP : `apiplatform` (référence) ou `vanilla`.
    'http' => 'apiplatform',
    // Persistance : `cqrs` (SQL pur) ou `doctrine` (ORM).
    'persistence' => 'cqrs',
    'db' => [
        'host' => 'localhost',
        'port' => 3306,
        'database' => 'todo',
        'username' => 'todo',
        // Lire le mot de passe dans un fichier à droits 600 HORS du dépôt et hors de src/ (tout src/
        // part au déploiement) plutôt que de l'écrire ici :
        // 'password' => trim((string) file_get_contents('/home/<compte>/<instance>/.dbpass')),
        'password' => '',
        'charset' => 'utf8mb4',
    ],
    // Secret du noyau Symfony : `openssl rand -hex 32`, tiré sur le serveur. Jamais de valeur ici.
    'secret' => '',
    // Adresse publique du site, par exemple https://<adresse>. Vide en local.
    'public_url' => '',
    // Inscription par l'API : `closed` en production (comptes créés par `php bin/account.php create`).
    'registration' => 'closed',
    // Journaux, sessions, compteurs : un dossier de l'instance, hors de public/.
    // 'var_dir' => '/home/<compte>/<instance>/var',
    'log_level' => 'notice',
    // Essais de connexion par adresse IP et par minute (0 = pas de plafond par adresse). À régler si
    // PHP ne voit qu'une seule adresse derrière le frontal de l'hébergeur.
    'login_ip_limit' => 50,
    // Sessions : inactivité et durée de vie maximales, en secondes (contrôlées à chaque requête).
    'session_idle' => 7200,
    'session_max' => 43200,
];

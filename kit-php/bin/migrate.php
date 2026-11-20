#!/usr/bin/env php
<?php

declare(strict_types=1);

/**
 * Outil de migration : php bin/migrate.php up|down|status
 *
 *   up      applique les migrations manquantes de database/migrations/pending/, dans l'ordre
 *   down    annule la dernière migration passée
 *   status  liste les migrations et leur état
 *
 * PDO seul, sans Composer : c'est une commande courte, jouable par SSH sur un hébergeur infogéré.
 * La connexion vient de la configuration de l'instance (src/Config.php). Code de sortie 0 = fait.
 */
use TodoApp\Adapter\Migration\Migrator;
use TodoApp\Config;
use TodoApp\Database;

require dirname(__DIR__) . '/src/bootstrap.php';

$command = $argv[1] ?? '';
if (!in_array($command, ['up', 'down', 'status'], true)) {
    fwrite(STDERR, "usage : php bin/migrate.php up|down|status\n");
    exit(2);
}

try {
    $config = Config::load();
    $dir = getenv('KIT_MIGRATIONS_DIR') ?: dirname(__DIR__) . '/database/migrations/pending';
    $migrator = new Migrator(Database::connect($config), $dir);

    if ($command === 'status') {
        $labels = ['applied' => 'appliquée', 'pending' => 'en attente', 'modified' => 'MODIFIÉE', 'missing' => 'ABSENTE'];
        foreach ($migrator->status() as $m) {
            printf("%-40s %-11s %s\n", $m['version'], $labels[$m['state']], $m['appliedAt'] ?? '');
        }
        exit(0);
    }
    if ($command === 'up') {
        $done = $migrator->up();
        foreach ($done as $version) {
            echo "  appliquée : $version\n";
        }
        printf("migrations : %d appliquée(s)\n", count($done));
        exit(0);
    }
    $undone = $migrator->down();
    echo $undone === null ? "migrations : rien à annuler\n" : "migrations : annulée $undone\n";
    exit(0);
} catch (PDOException $e) {
    // Jamais le DSN ni l'identifiant : le code SQLSTATE suffit à diagnostiquer.
    fwrite(STDERR, 'migrations : échec de base de données (SQLSTATE ' . $e->getCode() . ").\n");
    if (getenv('KIT_MIGRATE_VERBOSE')) {
        fwrite(STDERR, $e->getMessage() . "\n");
    }
    exit(1);
} catch (Throwable $e) {
    fwrite(STDERR, 'migrations : ' . $e->getMessage() . "\n");
    exit(1);
}

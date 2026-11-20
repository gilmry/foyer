<?php

declare(strict_types=1);

/**
 * Harnais : remet la base à zéro puis pose le schéma PAR L'OUTIL DE MIGRATION du kit (jamais en
 * exécutant un fichier SQL à la main). Joué avec le login applicatif sans privilège : il n'a de
 * droits que sur sa base, ce qui suffit. Réservé au harnais local — jamais sur un déploiement.
 */
use TodoApp\Adapter\Migration\Migrator;
use TodoApp\Config;
use TodoApp\Database;

require __DIR__ . '/../src/bootstrap.php';

$db = Database::connect(Config::load());
$db->exec('SET FOREIGN_KEY_CHECKS = 0');
foreach ($db->query('SHOW TABLES')->fetchAll(PDO::FETCH_COLUMN) as $table) {
    $db->exec('DROP TABLE `' . str_replace('`', '``', (string) $table) . '`');
}
$db->exec('SET FOREIGN_KEY_CHECKS = 1');

$done = (new Migrator($db, __DIR__ . '/../database/migrations/pending'))->up();
fwrite(STDOUT, sprintf("[kit] base remise à zéro, %d migration(s) appliquée(s)\n", count($done)));

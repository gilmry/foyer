#!/usr/bin/env php
<?php

declare(strict_types=1);

/**
 * Préchauffe le cache du noyau Symfony (conteneur compilé, routes) : php bin/warmup.php
 *
 * À jouer SUR LE POSTE, dans l'image PHP du kit, le dossier de la version étant monté au chemin
 * exact qu'il aura sur le serveur (le conteneur compilé contient des chemins absolus). C'est ce
 * que fait deploiement/alwaysdata/deployer.sh. Aucune valeur de l'instance n'entre dans ce cache :
 * le secret, le dossier d'état et le niveau de journal sont lus à l'exécution.
 * Ne touche pas à la base. Exige vendor/.
 */
use TodoApp\Adapter\Services;
use TodoApp\Config;
use TodoApp\Http\ApiPlatform\Kernel;

$root = dirname(__DIR__);
require $root . '/src/bootstrap.php';
require $root . '/vendor/autoload.php';

// Valeurs factices : rien de ce qui suit n'est écrit dans le cache.
$config = ['secret' => 'warmup', 'var_dir' => sys_get_temp_dir() . '/kit-warmup', 'log_level' => 'error']
    + ['http' => 'apiplatform', 'persistence' => 'cqrs', 'db' => [], 'public_url' => '', 'registration' => 'closed', 'version' => 'warmup', 'root' => $root];
@mkdir($config['var_dir'] . '/log', 0700, true);
Kernel::exportRuntime($config);

$kernel = new Kernel(new Services($config));
$kernel->boot();
$kernel->getContainer()->get('cache_warmer')->enableOptionalWarmers();
$kernel->getContainer()->get('cache_warmer')->warmUp($kernel->getCacheDir(), $kernel->getBuildDir());

echo 'cache du noyau préchauffé : ' . $kernel->getCacheDir() . "\n";

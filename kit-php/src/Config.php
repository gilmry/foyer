<?php

declare(strict_types=1);

namespace TodoApp;

use RuntimeException;

/**
 * Configuration de l'instance. Trois couches, de la plus faible à la plus forte :
 *
 *   1. les défauts ci-dessous (sûrs : inscription fermée) ;
 *   2. le FICHIER de configuration, hors de public/, droits 600, jamais versionné :
 *      `src/config.php` (sur un hébergeur : un lien vers le fichier de l'instance, écrit une fois
 *      par deploiement/alwaysdata/deployer.sh), ou le chemin donné par KIT_CONFIG ;
 *   3. les VARIABLES D'ENVIRONNEMENT, prioritaires : c'est par elles que le harnais choisit
 *      l'adaptateur HTTP et la persistance sans écrire de fichier.
 *
 * Sur un hébergeur infogéré on ne maîtrise pas l'environnement du PHP servi par Apache : c'est
 * donc le fichier qui y fait foi (question ouverte 1 de l'issue #34).
 */
final class Config
{
    public const HTTP = ['apiplatform', 'vanilla'];
    public const PERSISTENCE = ['cqrs', 'doctrine'];
    public const REGISTRATION = ['open', 'closed'];

    /** @return array<string,mixed> */
    public static function load(?string $root = null): array
    {
        $root ??= dirname(__DIR__);
        $config = [
            // API Platform / Symfony est l'adaptateur HTTP de référence.
            'http' => 'apiplatform',
            'persistence' => 'cqrs',
            'db' => [
                'host' => 'localhost',
                'port' => 3306,
                'database' => 'todo',
                'username' => 'todo',
                'password' => '',
                'charset' => 'utf8mb4',
            ],
            // Secret du noyau Symfony : aucun défaut. Sans lui, l'adaptateur de référence refuse de démarrer.
            'secret' => '',
            // Adresse publique (https://…) : fixe l'origine admise (CSRF), le drapeau Secure du
            // cookie de session et l'émission de HSTS. Vide = harnais local.
            'public_url' => '',
            'registration' => 'closed',
            // État de l'instance (journaux, sessions, compteurs) : survit aux changements de version.
            'var_dir' => $root . '/var',
            'log_level' => 'notice',
            // Essais de connexion par adresse IP et par minute, tous comptes confondus (0 = pas de
            // plafond par adresse). Le plafond par compte (5 par minute) ne se règle pas.
            'login_ip_limit' => 50,
            // Sessions : durée d'inactivité et durée de vie maximales, en secondes.
            'session_idle' => 7200,
            'session_max' => 43200,
        ];

        $file = self::env('KIT_CONFIG') ?? (is_file($root . '/src/config.php') ? $root . '/src/config.php' : null);
        if ($file !== null) {
            $fromFile = require $file;
            if (!is_array($fromFile)) {
                throw new RuntimeException('Le fichier de configuration doit renvoyer un tableau.');
            }
            $config = array_replace_recursive($config, $fromFile);
        }

        // Clé de configuration ← variable d'environnement (prioritaire).
        $env = [
            ['http', 'TODO_HTTP'], ['persistence', 'TODO_PERSISTENCE'], ['secret', 'KIT_SECRET'],
            ['public_url', 'KIT_PUBLIC_URL'], ['registration', 'KIT_REGISTRATION'],
            ['var_dir', 'KIT_VAR_DIR'], ['log_level', 'KIT_LOG_LEVEL'], ['login_ip_limit', 'KIT_LOGIN_IP_LIMIT'],
            ['session_idle', 'KIT_SESSION_IDLE'], ['session_max', 'KIT_SESSION_MAX'],
        ];
        foreach ($env as [$key, $name]) {
            $config[$key] = self::env($name) ?? $config[$key];
        }
        $dbEnv = ['host' => 'DB_HOST', 'port' => 'DB_PORT', 'database' => 'DB_NAME', 'username' => 'DB_USER', 'password' => 'DB_PASSWORD'];
        foreach ($dbEnv as $key => $name) {
            $config['db'][$key] = self::env($name) ?? $config['db'][$key];
        }
        $config['db']['port'] = (int) $config['db']['port'];
        foreach (['login_ip_limit', 'session_idle', 'session_max'] as $key) {
            $config[$key] = max(0, (int) $config[$key]);
        }
        $config['public_url'] = rtrim((string) $config['public_url'], '/');

        foreach (['http' => self::HTTP, 'persistence' => self::PERSISTENCE, 'registration' => self::REGISTRATION] as $key => $allowed) {
            if (!in_array($config[$key], $allowed, true)) {
                throw new RuntimeException(sprintf('Configuration : « %s » doit valoir %s.', $key, implode(' ou ', $allowed)));
            }
        }

        // Nom de la version servie : celui du dossier quand le kit est déployé sous versions/<nom>.
        $config['version'] = basename(dirname($root)) === 'versions' ? basename($root) : 'dev';
        $config['root'] = $root;

        return $config;
    }

    /** L'adresse publique est-elle en https ? Décide de Secure et de HSTS, sans regarder la requête. */
    public static function isHttps(array $config): bool
    {
        return str_starts_with((string) $config['public_url'], 'https://');
    }

    private static function env(string $name): ?string
    {
        $value = getenv($name);

        return $value === false || $value === '' ? null : $value;
    }
}

<?php

declare(strict_types=1);

namespace TodoApp\Http;

use TodoApp\Adapter\Services;
use TodoApp\Application;
use TodoApp\Config;

/**
 * Logique du contrôleur frontal (public/index.php), commune au serveur de l'hébergeur et au
 * serveur intégré du harnais (harness/dev-router.php) :
 *   - pose les en-têtes de sécurité ;
 *   - sert le document (public/index.html) ;
 *   - confie /api/* à l'adaptateur HTTP choisi par la configuration : `apiplatform` (référence)
 *     ou `vanilla` ;
 *   - répond 404 à tout le reste. Rien hors de public/ n'est lu sur demande du client.
 */
final class Front
{
    public static function run(string $root): void
    {
        $path = parse_url($_SERVER['REQUEST_URI'] ?? '/', PHP_URL_PATH) ?: '/';
        $isApi = $path === '/api' || str_starts_with($path, '/api/');

        try {
            $config = Config::load($root);
        } catch (\Throwable $e) {
            SecurityHeaders::emit(false);
            self::unavailable($isApi, $e);

            return;
        }
        SecurityHeaders::emit(Config::isHttps($config));

        if (!$isApi) {
            self::document($root, $path);

            return;
        }

        try {
            foreach (['log', 'sessions'] as $dir) {
                if (!is_dir($config['var_dir'] . '/' . $dir)) {
                    @mkdir($config['var_dir'] . '/' . $dir, 0700, true);
                }
            }
            if ($config['http'] === 'vanilla') {
                (new Application(new Services($config)))->handle();

                return;
            }
            self::apiPlatform($root, $config);
        } catch (\Throwable $e) {
            self::unavailable(true, $e);
        }
    }

    /** @param array<string,mixed> $config */
    private static function apiPlatform(string $root, array $config): void
    {
        if (strlen((string) $config['secret']) < 32) {
            throw new \RuntimeException('Configuration : le secret du noyau (clé « secret ») est absent ou trop court (32 caractères au moins).');
        }
        require $root . '/vendor/autoload.php';

        ApiPlatform\Kernel::exportRuntime($config);
        // Le schéma public vient de la configuration, pas de ce que le frontal de l'hébergeur laisse
        // voir : c'est lui qui décide du drapeau Secure du cookie de session.
        $_SERVER['HTTPS'] = Config::isHttps($config) ? 'on' : 'off';
        // Le routage ne dépend que de l'URI, quel que soit le serveur (Apache, FastCGI, php -S).
        $_SERVER['SCRIPT_NAME'] = '/index.php';
        $_SERVER['PHP_SELF'] = '/index.php';
        $_SERVER['SCRIPT_FILENAME'] = $root . '/public/index.php';
        unset($_SERVER['PATH_INFO'], $_SERVER['ORIG_PATH_INFO']);

        $kernel = new ApiPlatform\Kernel(new Services($config));
        $request = \Symfony\Component\HttpFoundation\Request::createFromGlobals();
        $response = $kernel->handle($request);
        $response->send();
        $kernel->terminate($request, $response);
    }

    private static function document(string $root, string $path): void
    {
        if ($path !== '/' && $path !== '/index.html') {
            http_response_code(404);
            header('Content-Type: text/plain; charset=utf-8');
            echo 'Introuvable.';

            return;
        }
        header('Content-Type: text/html; charset=utf-8');
        header('Cache-Control: no-cache');
        readfile($root . '/public/index.html');
    }

    /** 503 générique : ni trace, ni identifiant, ni nom d'hôte. Le détail va au journal du serveur. */
    private static function unavailable(bool $isApi, \Throwable $e): void
    {
        error_log('kit-php : ' . $e::class . ' (' . ($e instanceof \PDOException ? 'SQLSTATE ' . $e->getCode() : $e->getMessage()) . ')');
        if (headers_sent()) {
            return;
        }
        http_response_code(503);
        header('Cache-Control: no-store');
        if ($isApi) {
            header('Content-Type: ' . Problem::CONTENT_TYPE);
            echo Problem::encode(Problem::body(503));

            return;
        }
        header('Content-Type: text/plain; charset=utf-8');
        echo 'Service temporairement indisponible.';
    }
}

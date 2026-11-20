<?php

declare(strict_types=1);

namespace TodoApp\Http\ApiPlatform;

use ApiPlatform\Symfony\Bundle\ApiPlatformBundle;
use Psr\Log\LoggerInterface;
use Symfony\Bundle\FrameworkBundle\FrameworkBundle;
use Symfony\Bundle\FrameworkBundle\Kernel\MicroKernelTrait;
use Symfony\Bundle\SecurityBundle\SecurityBundle;
use Symfony\Component\DependencyInjection\Loader\Configurator\ContainerConfigurator;
use Symfony\Component\HttpKernel\Kernel as BaseKernel;
use Symfony\Component\HttpKernel\Log\Logger;
use Symfony\Component\Routing\Loader\Configurator\RoutingConfigurator;
use TodoApp\Adapter\Services;
use TodoApp\Application\Account\IssueAccessToken;
use TodoApp\Application\Account\RegisterAccount;
use TodoApp\Application\Account\ResolveAccessToken;
use TodoApp\Application\Account\RevokeAccessToken;
use TodoApp\Application\Todo\CreateTodo;
use TodoApp\Application\Todo\DeleteTodo;
use TodoApp\Application\Todo\GetTodo;
use TodoApp\Application\Todo\ListTodos;
use TodoApp\Application\Todo\ToggleTodo;
use TodoApp\Domain\Account\AccessTokenRepository;
use TodoApp\Domain\Account\AccountRepository;
use TodoApp\Domain\Account\CurrentUser;
use TodoApp\Domain\Account\PasswordHasher;
use TodoApp\Domain\Account\TokenGenerator;
use TodoApp\Domain\Todo\Clock;
use TodoApp\Domain\Todo\IdGenerator;
use TodoApp\Domain\Todo\TodoRepository;
use TodoApp\Http\ApiPlatform\Security\AccountUserProvider;
use TodoApp\Http\ApiPlatform\Security\AuthenticationResponder;
use TodoApp\Http\ApiPlatform\Security\BearerRequestMatcher;
use TodoApp\Http\ApiPlatform\Security\BearerTokenHandler;
use TodoApp\Http\ApiPlatform\Security\LoginLimiter;
use TodoApp\Http\ApiPlatform\Security\OriginGuard;
use TodoApp\Http\ApiPlatform\Security\SecurityUser;
use TodoApp\Http\ApiPlatform\Security\SessionLifetimeGuard;
use TodoApp\Http\ApiPlatform\Security\SymfonyCurrentUser;
use TodoApp\Http\ApiPlatform\Security\SymfonyPasswordHasher;
use TodoApp\Http\ApiPlatform\Security\TokenIssueResponder;

use function Symfony\Component\DependencyInjection\Loader\Configurator\service;

/**
 * Micro-noyau Symfony de l'adaptateur HTTP de référence : API Platform pour la ressource Todo,
 * SecurityBundle pour l'authentification (ADR-001).
 *
 * Aucune valeur de l'instance n'est figée dans le conteneur compilé : le secret, le dossier
 * d'état et le niveau de journal sont lus à l'exécution (%env(KIT_RT_…)%), posés par
 * exportRuntime() depuis la configuration de l'instance. Le cache compilé peut donc être
 * construit sur le poste et servi tel quel sur le serveur.
 */
final class Kernel extends BaseKernel
{
    use MicroKernelTrait;

    public const SESSION_COOKIE = 'kit_session';

    public function __construct(private readonly Services $kitServices)
    {
        parent::__construct('prod', false);
    }

    /**
     * Pose les valeurs que le conteneur lit à l'exécution.
     *
     * @param array<string,mixed> $config
     */
    public static function exportRuntime(array $config): void
    {
        $_SERVER['KIT_RT_SECRET'] = (string) $config['secret'];
        $_SERVER['KIT_RT_VAR_DIR'] = (string) $config['var_dir'];
        $_SERVER['KIT_RT_LOG_LEVEL'] = (string) $config['log_level'];
    }

    public function registerBundles(): iterable
    {
        return [new FrameworkBundle(), new SecurityBundle(), new ApiPlatformBundle()];
    }

    public function boot(): void
    {
        parent::boot();
        // Racine de composition du kit (configuration + adaptateurs) : fournie à l'exécution.
        $this->container->set(Services::class, $this->kitServices);
    }

    protected function configureContainer(ContainerConfigurator $c): void
    {
        $c->extension('framework', [
            'secret' => '%env(KIT_RT_SECRET)%',
            'test' => false,
            'http_method_override' => false,
            'handle_all_throwables' => true,
            'router' => ['utf8' => true],
            'php_errors' => ['log' => true],
            'session' => [
                // Fichiers de session dans l'état de l'instance : ils survivent à un changement de version.
                'handler_id' => 'session.handler.native_file',
                'save_path' => '%env(KIT_RT_VAR_DIR)%/sessions',
                'name' => self::SESSION_COOKIE,
                'cookie_httponly' => true,
                'cookie_samesite' => 'strict',
                // « auto » = Secure quand la requête est en https ; Front force ce schéma d'après
                // l'adresse publique de la configuration.
                'cookie_secure' => 'auto',
                'cookie_lifetime' => 0,
                // Purge des fichiers de session par PHP : une requête sur cent, quel que soit le
                // réglage de l'hébergeur. L'expiration elle-même est tenue par SessionLifetimeGuard.
                'gc_probability' => 1,
                'gc_divisor' => 100,
                'gc_maxlifetime' => 43200,
            ],
            // Cache applicatif : état de l'instance.
            'cache' => ['directory' => '%env(KIT_RT_VAR_DIR)%/pools'],
            'validation' => ['enabled' => true, 'email_validation_mode' => 'html5'],
        ]);

        $c->extension('security', [
            'password_hashers' => [SecurityUser::class => 'auto'],
            'providers' => ['accounts' => ['id' => AccountUserProvider::class]],
            'firewalls' => [
                // 1. Émission d'un jeton porteur contre courriel + mot de passe. Sans état.
                'token_issue' => [
                    'pattern' => '^/api/tokens$',
                    'methods' => ['POST'],
                    'stateless' => true,
                    'provider' => 'accounts',
                    'json_login' => [
                        'check_path' => '/api/tokens',
                        'username_path' => 'email',
                        'password_path' => 'password',
                        'success_handler' => TokenIssueResponder::class,
                        'failure_handler' => AuthenticationResponder::class,
                    ],
                    'login_throttling' => ['limiter' => LoginLimiter::class],
                ],
                // 2. Toute requête qui porte un en-tête Authorization : jeton porteur, sans état,
                //    donc jamais de cookie de session pour un client d'API.
                'bearer' => [
                    'request_matcher' => BearerRequestMatcher::class,
                    'stateless' => true,
                    'provider' => 'accounts',
                    'access_token' => [
                        'token_handler' => BearerTokenHandler::class,
                        'failure_handler' => AuthenticationResponder::class,
                    ],
                    'entry_point' => AuthenticationResponder::class,
                    'access_denied_handler' => AuthenticationResponder::class,
                ],
                // 3. Le reste de /api : session par cookie pour le front îlots.
                'main' => [
                    'pattern' => '^/api',
                    'lazy' => true,
                    'provider' => 'accounts',
                    'json_login' => [
                        'check_path' => '/api/login',
                        'username_path' => 'email',
                        'password_path' => 'password',
                        'success_handler' => AuthenticationResponder::class,
                        'failure_handler' => AuthenticationResponder::class,
                    ],
                    'logout' => ['path' => '/api/logout', 'delete_cookies' => [self::SESSION_COOKIE => []]],
                    'login_throttling' => ['limiter' => LoginLimiter::class],
                    'entry_point' => AuthenticationResponder::class,
                    'access_denied_handler' => AuthenticationResponder::class,
                ],
            ],
            // Tout /api est fermé, sauf la connexion, l'inscription, l'émission de jeton et la sonde.
            'access_control' => [
                ['path' => '^/api/(login|register|tokens)$', 'methods' => ['POST'], 'roles' => 'PUBLIC_ACCESS'],
                ['path' => '^/api/health$', 'methods' => ['GET'], 'roles' => 'PUBLIC_ACCESS'],
                ['path' => '^/api', 'roles' => 'ROLE_USER'],
            ],
        ]);

        $c->extension('api_platform', [
            'title' => 'Todo — API',
            'description' => 'Adaptateur HTTP de référence du kit Foyer PHP (API Platform / Symfony).',
            'version' => '2.0.0',
            'formats' => ['json' => ['mime_types' => ['application/json']]],
            'patch_formats' => ['json' => ['mime_types' => ['application/merge-patch+json', 'application/json']]],
            'error_formats' => ['jsonproblem' => ['mime_types' => ['application/problem+json']]],
            'docs_formats' => ['jsonopenapi' => ['mime_types' => ['application/vnd.openapi+json']]],
            'defaults' => ['pagination_enabled' => false],
            'mapping' => ['paths' => [__DIR__ . '/Resource']],
            'enable_swagger_ui' => false,
            'enable_re_doc' => false,
            'enable_entrypoint' => false,
            'enable_docs' => true,
        ]);

        $services = $c->services()->defaults()->autowire()->autoconfigure();

        // Journal du noyau : un fichier de l'instance, pas la sortie d'erreur ni le dossier temporaire.
        $services->set('logger', Logger::class)
            ->args(['%env(KIT_RT_LOG_LEVEL)%', '%env(KIT_RT_VAR_DIR)%/log/kit.log']);
        $services->alias(LoggerInterface::class, 'logger');

        // Racine de composition du kit, puis les ports du domaine servis par ses adaptateurs.
        $services->set(Services::class)->synthetic()->public();
        $ports = [
            TodoRepository::class => 'todos', AccountRepository::class => 'accounts',
            AccessTokenRepository::class => 'tokens', TokenGenerator::class => 'tokenGenerator',
            Clock::class => 'clock', IdGenerator::class => 'ids',
        ];
        foreach ($ports as $port => $method) {
            $services->set($port)->factory([service(Services::class), $method])->autowire(false);
        }
        $services->set(SymfonyPasswordHasher::class);
        $services->alias(PasswordHasher::class, SymfonyPasswordHasher::class);
        $services->set(SymfonyCurrentUser::class);
        $services->alias(CurrentUser::class, SymfonyCurrentUser::class);

        // Cas d'usage : les MÊMES que l'adaptateur vanilla.
        foreach ([CreateTodo::class, ListTodos::class, GetTodo::class, ToggleTodo::class, DeleteTodo::class,
            RegisterAccount::class, IssueAccessToken::class, ResolveAccessToken::class, RevokeAccessToken::class] as $useCase) {
            $services->set($useCase);
        }

        // Adaptateur HTTP : sécurité, erreurs au format problème, ressources.
        foreach ([AccountUserProvider::class, AuthenticationResponder::class, TokenIssueResponder::class,
            BearerRequestMatcher::class, BearerTokenHandler::class, OriginGuard::class, ProblemSubscriber::class,
            LoginLimiter::class, SessionLifetimeGuard::class,
            State\TodoStateProvider::class, State\TodoStateProcessor::class] as $class) {
            $services->set($class);
        }
        $services->set(AccountController::class)->public()->tag('controller.service_arguments');
        $services->set(OpenApiFactory::class)
            ->decorate('api_platform.openapi.factory')
            ->args([service('.inner')])
            ->autowire(false);
    }

    protected function configureRoutes(RoutingConfigurator $routes): void
    {
        $routes->import('.', 'api_platform')->prefix('/api');

        $c = AccountController::class;
        $routes->add('kit_health', '/api/health')->controller([$c, 'health'])->methods(['GET']);
        $routes->add('kit_me', '/api/me')->controller([$c, 'me'])->methods(['GET']);
        $routes->add('kit_register', '/api/register')->controller([$c, 'register'])->methods(['POST']);
        $routes->add('kit_token_revoke', '/api/tokens/current')->controller([$c, 'revokeToken'])->methods(['DELETE']);
        // Ces trois routes sont traitées par les pare-feu (json_login, logout). Le contrôleur ne
        // répond que si la requête n'a pas la forme attendue.
        $routes->add('kit_login', '/api/login')->controller([$c, 'malformedLogin'])->methods(['POST']);
        $routes->add('kit_token_issue', '/api/tokens')->controller([$c, 'malformedLogin'])->methods(['POST']);
        $routes->add('kit_logout', '/api/logout')->controller([$c, 'malformedLogin'])->methods(['POST']);
    }

    public function getProjectDir(): string
    {
        return \dirname(__DIR__, 3);
    }

    /**
     * Le conteneur compilé suit la VERSION du code (il en dérive) : il vit dans le var/ de la
     * version, préchauffé avant l'envoi. L'état (journaux, sessions, compteurs) vit dans le var/
     * de l'instance (KIT_RT_VAR_DIR).
     */
    public function getCacheDir(): string
    {
        return $this->getProjectDir() . '/var/cache/' . $this->environment;
    }

    public function getBuildDir(): string
    {
        return $this->getCacheDir();
    }

    /**
     * Paramètre `kernel.logs_dir`, figé dans le conteneur compilé : il ne doit donc rien devoir à
     * la machine qui préchauffe le cache. Le journal réel suit KIT_RT_VAR_DIR (service `logger`).
     */
    public function getLogDir(): string
    {
        return $this->getProjectDir() . '/var/log';
    }
}

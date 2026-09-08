<?php

declare(strict_types=1);

namespace TodoApp\Http\ApiPlatform;

use ApiPlatform\Symfony\Bundle\ApiPlatformBundle;
use Symfony\Bundle\FrameworkBundle\FrameworkBundle;
use Symfony\Bundle\FrameworkBundle\Kernel\MicroKernelTrait;
use Symfony\Component\DependencyInjection\Loader\Configurator\ContainerConfigurator;
use Symfony\Component\HttpKernel\Kernel as BaseKernel;
use Symfony\Component\Routing\Loader\Configurator\RoutingConfigurator;

/** Micro-kernel Symfony minimal pour exposer le périmètre Todo via API Platform. */
final class Kernel extends BaseKernel
{
    use MicroKernelTrait;

    public function registerBundles(): iterable
    {
        return [new FrameworkBundle(), new ApiPlatformBundle()];
    }

    protected function configureContainer(ContainerConfigurator $c): void
    {
        $c->extension('framework', [
            'secret' => 'kit-foyer',
            'test' => false,
            'http_method_override' => false,
            'handle_all_throwables' => true,
            'router' => ['utf8' => true],
            'php_errors' => ['log' => true],
        ]);

        $c->extension('api_platform', [
            'title' => 'Todo — API Platform',
            'version' => '1.0.0',
            'formats' => ['json' => ['mime_types' => ['application/json']]],
            'patch_formats' => ['json' => ['mime_types' => ['application/merge-patch+json', 'application/json']]],
            'defaults' => ['pagination_enabled' => false],
            'mapping' => ['paths' => [__DIR__]],
            'enable_swagger_ui' => false,
            // Exceptions du domaine → codes HTTP (l'adaptateur traduit, le domaine ignore HTTP).
            'exception_to_status' => [
                \TodoApp\Domain\Todo\TodoValidationException::class => 400,
                \TodoApp\Domain\Todo\TodoNotFoundException::class => 404,
            ],
        ]);

        $services = $c->services()->defaults()->autowire()->autoconfigure();
        $services->set(TodoStateProvider::class);
        $services->set(TodoStateProcessor::class);
    }

    protected function configureRoutes(RoutingConfigurator $routes): void
    {
        $routes->import('.', 'api_platform')->prefix('/api');
    }

    public function getProjectDir(): string
    {
        return \dirname(__DIR__, 3);
    }

    public function getCacheDir(): string
    {
        return ($_SERVER['KERNEL_CACHE_DIR'] ?? sys_get_temp_dir() . '/todo-ap-cache') . '/' . $this->environment;
    }

    public function getLogDir(): string
    {
        return $_SERVER['KERNEL_LOG_DIR'] ?? sys_get_temp_dir() . '/todo-ap-log';
    }
}

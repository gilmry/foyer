<?php

declare(strict_types=1);

use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpKernel\Exception\HttpExceptionInterface;
use Symfony\Component\HttpKernel\HttpKernelInterface;
use TodoApp\Domain\Todo\TodoNotFoundException;
use TodoApp\Domain\Todo\TodoValidationException;
use TodoApp\Http\ApiPlatform\Kernel;

require dirname(__DIR__) . '/vendor/autoload.php';

$kernel = new Kernel('prod', false);
$request = Request::createFromGlobals();

// L'adaptateur HTTP traduit les exceptions du DOMAINE en codes HTTP (le domaine ignore HTTP).
// catch:false → les exceptions remontent ici plutôt que d'être rendues par le kernel.
try {
    $response = $kernel->handle($request, HttpKernelInterface::MAIN_REQUEST, false);
} catch (TodoValidationException $e) {
    $response = new JsonResponse(['errors' => $e->errors()], 400);
} catch (TodoNotFoundException $e) {
    $response = new JsonResponse(['error' => $e->getMessage()], 404);
} catch (HttpExceptionInterface $e) {
    $response = new JsonResponse(['error' => $e->getMessage()], $e->getStatusCode());
} catch (Throwable $e) {
    $response = new JsonResponse(['error' => 'Erreur interne.'], 500);
}

$response->send();
$kernel->terminate($request, $response);

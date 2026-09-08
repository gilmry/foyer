<?php

declare(strict_types=1);

namespace TodoApp\Http\ApiPlatform;

use ApiPlatform\Metadata\DeleteOperationInterface;
use ApiPlatform\Metadata\Operation;
use ApiPlatform\Metadata\Post;
use ApiPlatform\State\ProcessorInterface;
use TodoApp\Adapter\Todo\RealClock;
use TodoApp\Adapter\Todo\UuidGenerator;
use TodoApp\Application\Todo\CreateTodo;
use TodoApp\Application\Todo\DeleteTodo;
use TodoApp\Application\Todo\ToggleTodo;

/** Côté ÉCRITURE — traduit les opérations HTTP en use-cases du domaine (POST/PATCH/DELETE). */
final class TodoStateProcessor implements ProcessorInterface
{
    public function process($data, Operation $operation, array $uriVariables = [], array $context = []): mixed
    {
        $repo = RepoBuilder::make();

        if ($operation instanceof DeleteOperationInterface) {
            (new DeleteTodo($repo))->execute((string) $uriVariables['id']);
            return null; // 204
        }

        if ($operation instanceof Post) {
            // TodoValidationException → 400 via exception_to_status (cf. Kernel).
            $todo = (new CreateTodo($repo, new RealClock(), new UuidGenerator()))
                ->execute(['title' => $data->title]);

            return TodoResource::fromDomain($todo); // 201
        }

        // Patch → bascule du statut (l'id inexistant a déjà donné 404 via le provider).
        $todo = (new ToggleTodo($repo, new RealClock()))->execute((string) $uriVariables['id']);

        return TodoResource::fromDomain($todo); // 200
    }
}

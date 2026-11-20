<?php

declare(strict_types=1);

namespace TodoApp\Http\ApiPlatform\State;

use ApiPlatform\Metadata\DeleteOperationInterface;
use ApiPlatform\Metadata\Operation;
use ApiPlatform\Metadata\Post;
use ApiPlatform\State\ProcessorInterface;
use TodoApp\Application\Todo\CreateTodo;
use TodoApp\Application\Todo\DeleteTodo;
use TodoApp\Application\Todo\ToggleTodo;
use TodoApp\Http\ApiPlatform\Resource\TodoInput;
use TodoApp\Http\ApiPlatform\Resource\TodoResource;

/** Côté ÉCRITURE — traduit les opérations HTTP en cas d'usage (POST / PATCH / DELETE). */
final class TodoStateProcessor implements ProcessorInterface
{
    public function __construct(
        private readonly CreateTodo $create,
        private readonly ToggleTodo $toggle,
        private readonly DeleteTodo $delete,
    ) {
    }

    public function process(mixed $data, Operation $operation, array $uriVariables = [], array $context = []): mixed
    {
        if ($operation instanceof DeleteOperationInterface) {
            $this->delete->execute((string) $uriVariables['id']);

            return null; // 204
        }

        if ($operation instanceof Post) {
            // Seul le libellé passe au cas d'usage : le propriétaire vient de l'identité.
            $title = $data instanceof TodoInput ? (string) $data->title : '';

            return TodoResource::fromDomain($this->create->execute(['title' => $title])); // 201
        }

        // PATCH → bascule du statut (une tâche absente ou d'autrui a déjà donné 404 par le provider).
        return TodoResource::fromDomain($this->toggle->execute((string) $uriVariables['id'])); // 200
    }
}

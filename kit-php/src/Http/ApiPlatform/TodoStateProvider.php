<?php

declare(strict_types=1);

namespace TodoApp\Http\ApiPlatform;

use ApiPlatform\Metadata\CollectionOperationInterface;
use ApiPlatform\Metadata\Operation;
use ApiPlatform\State\ProviderInterface;

/** Côté LECTURE — alimente API Platform depuis le repository du domaine (GET collection & item). */
final class TodoStateProvider implements ProviderInterface
{
    public function provide(Operation $operation, array $uriVariables = [], array $context = []): object|array|null
    {
        $repo = RepoBuilder::make();

        if ($operation instanceof CollectionOperationInterface) {
            return array_map(
                static fn ($t) => TodoResource::fromDomain($t),
                $repo->findAll(),
            );
        }

        $todo = $repo->find((string) ($uriVariables['id'] ?? ''));

        // null → API Platform répond 404 (avant tout processor).
        return $todo ? TodoResource::fromDomain($todo) : null;
    }
}

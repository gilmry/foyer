<?php

declare(strict_types=1);

namespace TodoApp\Http\ApiPlatform\State;

use ApiPlatform\Metadata\CollectionOperationInterface;
use ApiPlatform\Metadata\Operation;
use ApiPlatform\State\ProviderInterface;
use TodoApp\Application\Todo\GetTodo;
use TodoApp\Application\Todo\ListTodos;
use TodoApp\Domain\Todo\TodoNotFoundException;
use TodoApp\Http\ApiPlatform\Resource\TodoResource;

/** Côté LECTURE — alimente API Platform par les cas d'usage (liste bornée, lecture d'une tâche). */
final class TodoStateProvider implements ProviderInterface
{
    public function __construct(private readonly ListTodos $list, private readonly GetTodo $get)
    {
    }

    public function provide(Operation $operation, array $uriVariables = [], array $context = []): object|array|null
    {
        if ($operation instanceof CollectionOperationInterface) {
            $filters = $context['filters'] ?? [];

            return array_map(
                TodoResource::fromView(...),
                $this->list->execute(self::int($filters['limit'] ?? null, ListTodos::DEFAULT_LIMIT), self::int($filters['offset'] ?? null, 0)),
            );
        }

        try {
            return TodoResource::fromDomain($this->get->execute((string) ($uriVariables['id'] ?? '')));
        } catch (TodoNotFoundException) {
            // null → 404, que la tâche n'existe pas ou qu'elle soit à quelqu'un d'autre.
            return null;
        }
    }

    private static function int(mixed $value, int $default): int
    {
        return is_scalar($value) && preg_match('/^\d{1,9}$/', (string) $value) ? (int) $value : $default;
    }
}

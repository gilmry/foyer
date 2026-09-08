<?php

declare(strict_types=1);

namespace TodoApp\Application\Todo;

use TodoApp\Domain\Todo\Todo;
use TodoApp\Domain\Todo\TodoRepository;

/** Cas d'usage : lister les tâches (vues sérialisées, ordre stable du repository). */
final class ListTodos
{
    public function __construct(private readonly TodoRepository $todos)
    {
    }

    /** @return list<array{id:string,title:string,done:bool,createdAt:string,updatedAt:string}> */
    public function execute(): array
    {
        return array_map(static fn (Todo $t): array => $t->toView(), $this->todos->findAll());
    }
}

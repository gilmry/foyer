<?php

declare(strict_types=1);

namespace TodoApp\Application\Todo;

use TodoApp\Domain\Account\CurrentUser;
use TodoApp\Domain\Todo\Todo;
use TodoApp\Domain\Todo\TodoRepository;

/** Cas d'usage : lister les tâches du compte courant (vues sérialisées, ordre stable, liste bornée). */
final class ListTodos
{
    public const DEFAULT_LIMIT = 50;
    public const MAX_LIMIT = 100;

    public function __construct(
        private readonly TodoRepository $todos,
        private readonly CurrentUser $user,
    ) {
    }

    /** @return list<array{id:string,title:string,done:bool,createdAt:string,updatedAt:string}> */
    public function execute(int $limit = self::DEFAULT_LIMIT, int $offset = 0): array
    {
        // Borne : une collection n'est jamais rendue en entier, quelle que soit la demande.
        $limit = max(1, min(self::MAX_LIMIT, $limit));
        $offset = max(0, $offset);

        return array_map(
            static fn (Todo $t): array => $t->toView(),
            $this->todos->findAll($this->user->id(), $limit, $offset),
        );
    }
}

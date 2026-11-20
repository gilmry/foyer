<?php

declare(strict_types=1);

namespace TodoApp\Application\Todo;

use TodoApp\Domain\Account\CurrentUser;
use TodoApp\Domain\Todo\Todo;
use TodoApp\Domain\Todo\TodoNotFoundException;
use TodoApp\Domain\Todo\TodoRepository;

/** Cas d'usage : lire une tâche du compte courant. */
final class GetTodo
{
    public function __construct(
        private readonly TodoRepository $todos,
        private readonly CurrentUser $user,
    ) {
    }

    /** @throws TodoNotFoundException */
    public function execute(string $id): Todo
    {
        return $this->todos->find($this->user->id(), $id) ?? throw TodoNotFoundException::withId($id);
    }
}

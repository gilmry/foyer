<?php

declare(strict_types=1);

namespace TodoApp\Application\Todo;

use TodoApp\Domain\Account\CurrentUser;
use TodoApp\Domain\Todo\TodoNotFoundException;
use TodoApp\Domain\Todo\TodoRepository;

/** Cas d'usage : supprimer une tâche du compte courant. */
final class DeleteTodo
{
    public function __construct(
        private readonly TodoRepository $todos,
        private readonly CurrentUser $user,
    ) {
    }

    /** @throws TodoNotFoundException */
    public function execute(string $id): void
    {
        $ownerId = $this->user->id();
        if ($this->todos->find($ownerId, $id) === null) {
            throw TodoNotFoundException::withId($id);
        }

        $this->todos->delete($ownerId, $id);
    }
}

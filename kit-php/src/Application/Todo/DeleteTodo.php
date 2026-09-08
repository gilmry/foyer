<?php

declare(strict_types=1);

namespace TodoApp\Application\Todo;

use TodoApp\Domain\Todo\TodoNotFoundException;
use TodoApp\Domain\Todo\TodoRepository;

/** Cas d'usage : supprimer une tâche. */
final class DeleteTodo
{
    public function __construct(private readonly TodoRepository $todos)
    {
    }

    /**
     * @return array{deleted:bool}
     * @throws TodoNotFoundException
     */
    public function execute(string $id): array
    {
        if ($this->todos->find($id) === null) {
            throw TodoNotFoundException::withId($id);
        }

        $this->todos->delete($id);

        return ['deleted' => true];
    }
}

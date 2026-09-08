<?php

declare(strict_types=1);

namespace TodoApp\Application\Todo;

use TodoApp\Domain\Todo\Clock;
use TodoApp\Domain\Todo\Todo;
use TodoApp\Domain\Todo\TodoNotFoundException;
use TodoApp\Domain\Todo\TodoRepository;

/** Cas d'usage : basculer le statut d'une tâche (à faire ↔ faite). */
final class ToggleTodo
{
    public function __construct(
        private readonly TodoRepository $todos,
        private readonly Clock $clock,
    ) {
    }

    /** @throws TodoNotFoundException */
    public function execute(string $id): Todo
    {
        $todo = $this->todos->find($id);
        if ($todo === null) {
            throw TodoNotFoundException::withId($id);
        }

        $toggled = $todo->toggled($this->clock->now());
        $this->todos->save($toggled);

        return $toggled;
    }
}

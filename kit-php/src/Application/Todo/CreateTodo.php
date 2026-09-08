<?php

declare(strict_types=1);

namespace TodoApp\Application\Todo;

use TodoApp\Domain\Todo\Clock;
use TodoApp\Domain\Todo\IdGenerator;
use TodoApp\Domain\Todo\Todo;
use TodoApp\Domain\Todo\TodoRepository;
use TodoApp\Domain\Todo\TodoRules;
use TodoApp\Domain\Todo\TodoValidationException;

/** Cas d'usage : créer une tâche. Valide, construit l'entité, persiste. */
final class CreateTodo
{
    public function __construct(
        private readonly TodoRepository $todos,
        private readonly Clock $clock,
        private readonly IdGenerator $ids,
    ) {
    }

    /**
     * @param array<string,mixed> $input
     * @throws TodoValidationException
     */
    public function execute(array $input): Todo
    {
        $errors = TodoRules::validate($input);
        if ($errors !== []) {
            throw new TodoValidationException($errors);
        }

        $now = $this->clock->now();
        $todo = new Todo(
            $this->ids->uuid(),
            TodoRules::normalizeTitle((string) $input['title']),
            false,
            $now,
            $now,
        );

        $this->todos->save($todo);

        return $todo;
    }
}

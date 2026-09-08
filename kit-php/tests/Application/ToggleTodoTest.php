<?php

declare(strict_types=1);

namespace TodoApp\Tests\Application;

use PHPUnit\Framework\TestCase;
use TodoApp\Application\Todo\CreateTodo;
use TodoApp\Application\Todo\ToggleTodo;
use TodoApp\Domain\Todo\TodoNotFoundException;
use TodoApp\Tests\Fakes\FakeClock;
use TodoApp\Tests\Fakes\FakeIdGenerator;
use TodoApp\Tests\Fakes\FakeTodoRepository;

final class ToggleTodoTest extends TestCase
{
    private FakeTodoRepository $repo;
    private ToggleTodo $uc;

    protected function setUp(): void
    {
        $this->repo = new FakeTodoRepository();
        $this->uc = new ToggleTodo($this->repo, new FakeClock());
    }

    private function seed(): string
    {
        $todo = (new CreateTodo($this->repo, new FakeClock(), new FakeIdGenerator()))
            ->execute(['title' => 'tâche']);

        return $todo->id();
    }

    /** @happy — open → done → open, persisté */
    public function testToggleFlipsAndPersists(): void
    {
        $id = $this->seed();
        self::assertTrue($this->uc->execute($id)->isDone());
        self::assertFalse($this->uc->execute($id)->isDone());
        self::assertFalse($this->repo->find($id)->isDone());
    }

    /** @negative — id inexistant → TodoNotFoundException (→ 404) */
    public function testToggleUnknownIdThrows(): void
    {
        $this->expectException(TodoNotFoundException::class);
        $this->uc->execute('inconnu');
    }
}

<?php

declare(strict_types=1);

namespace TodoApp\Tests\Application;

use PHPUnit\Framework\TestCase;
use TodoApp\Application\Todo\CreateTodo;
use TodoApp\Application\Todo\DeleteTodo;
use TodoApp\Domain\Todo\TodoNotFoundException;
use TodoApp\Tests\Fakes\FakeClock;
use TodoApp\Tests\Fakes\FakeIdGenerator;
use TodoApp\Tests\Fakes\FakeTodoRepository;

final class DeleteTodoTest extends TestCase
{
    private FakeTodoRepository $repo;
    private DeleteTodo $uc;

    protected function setUp(): void
    {
        $this->repo = new FakeTodoRepository();
        $this->uc = new DeleteTodo($this->repo);
    }

    /** @happy — suppression → absente */
    public function testDeleteRemovesTodo(): void
    {
        $id = (new CreateTodo($this->repo, new FakeClock(), new FakeIdGenerator()))
            ->execute(['title' => 'tâche'])->id();

        self::assertSame(['deleted' => true], $this->uc->execute($id));
        self::assertNull($this->repo->find($id));
    }

    /** @negative — id inexistant → TodoNotFoundException (→ 404) */
    public function testDeleteUnknownIdThrows(): void
    {
        $this->expectException(TodoNotFoundException::class);
        $this->uc->execute('inconnu');
    }
}

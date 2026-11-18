<?php

declare(strict_types=1);

namespace TodoApp\Tests\Application;

use PHPUnit\Framework\TestCase;
use TodoApp\Application\Todo\CreateTodo;
use TodoApp\Application\Todo\GetTodo;
use TodoApp\Application\Todo\ToggleTodo;
use TodoApp\Domain\Todo\TodoNotFoundException;
use TodoApp\Tests\Fakes\FakeClock;
use TodoApp\Tests\Fakes\FakeCurrentUser;
use TodoApp\Tests\Fakes\FakeIdGenerator;
use TodoApp\Tests\Fakes\FakeTodoRepository;

final class ToggleTodoTest extends TestCase
{
    private FakeTodoRepository $repo;
    private ToggleTodo $uc;

    protected function setUp(): void
    {
        $this->repo = new FakeTodoRepository();
        $this->uc = new ToggleTodo($this->repo, new FakeClock(), new FakeCurrentUser('compte-a'));
    }

    private function seed(string $owner = 'compte-a'): string
    {
        $todo = (new CreateTodo($this->repo, new FakeClock(), new FakeIdGenerator(), new FakeCurrentUser($owner)))
            ->execute(['title' => 'tâche']);

        return $todo->id();
    }

    /** @happy — open → done → open, persisté */
    public function testToggleFlipsAndPersists(): void
    {
        $id = $this->seed();
        self::assertTrue($this->uc->execute($id)->isDone());
        self::assertFalse($this->uc->execute($id)->isDone());
        self::assertFalse($this->repo->find('compte-a', $id)->isDone());
    }

    /** @negative — id inexistant → TodoNotFoundException (→ 404) */
    public function testToggleUnknownIdThrows(): void
    {
        $this->expectException(TodoNotFoundException::class);
        $this->uc->execute('inconnu');
    }

    /** @edge — la tâche d'autrui : introuvable, et inchangée */
    public function testToggleSomeoneElsesTodoThrowsAndChangesNothing(): void
    {
        $id = $this->seed('compte-b');
        try {
            $this->uc->execute($id);
            self::fail('TodoNotFoundException attendue');
        } catch (TodoNotFoundException) {
        }
        self::assertFalse($this->repo->find('compte-b', $id)->isDone());
    }

    /** @edge — lire la tâche d'autrui : introuvable */
    public function testGetSomeoneElsesTodoThrows(): void
    {
        $id = $this->seed('compte-b');
        self::assertSame($id, (new GetTodo($this->repo, new FakeCurrentUser('compte-b')))->execute($id)->id());
        $this->expectException(TodoNotFoundException::class);
        (new GetTodo($this->repo, new FakeCurrentUser('compte-a')))->execute($id);
    }
}

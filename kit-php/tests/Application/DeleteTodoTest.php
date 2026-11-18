<?php

declare(strict_types=1);

namespace TodoApp\Tests\Application;

use PHPUnit\Framework\TestCase;
use TodoApp\Application\Todo\CreateTodo;
use TodoApp\Application\Todo\DeleteTodo;
use TodoApp\Domain\Todo\TodoNotFoundException;
use TodoApp\Tests\Fakes\FakeClock;
use TodoApp\Tests\Fakes\FakeCurrentUser;
use TodoApp\Tests\Fakes\FakeIdGenerator;
use TodoApp\Tests\Fakes\FakeTodoRepository;

final class DeleteTodoTest extends TestCase
{
    private FakeTodoRepository $repo;
    private FakeCurrentUser $user;
    private DeleteTodo $uc;

    protected function setUp(): void
    {
        $this->repo = new FakeTodoRepository();
        $this->user = new FakeCurrentUser('compte-a');
        $this->uc = new DeleteTodo($this->repo, $this->user);
    }

    private function seed(string $owner): string
    {
        return (new CreateTodo($this->repo, new FakeClock(), new FakeIdGenerator(), new FakeCurrentUser($owner)))
            ->execute(['title' => 'tâche'])->id();
    }

    /** @happy — suppression → absente */
    public function testDeleteRemovesTodo(): void
    {
        $id = $this->seed('compte-a');
        $this->uc->execute($id);
        self::assertNull($this->repo->find('compte-a', $id));
    }

    /** @negative — id inexistant → TodoNotFoundException (→ 404) */
    public function testDeleteUnknownIdThrows(): void
    {
        $this->expectException(TodoNotFoundException::class);
        $this->uc->execute('inconnu');
    }

    /** @edge — la tâche d'autrui : même exception, même message que l'inexistante, et elle reste */
    public function testDeleteSomeoneElsesTodoIsIndistinguishableFromUnknown(): void
    {
        $id = $this->seed('compte-b');
        $messages = [];
        foreach ([$id, 'inconnu'] as $target) {
            try {
                $this->uc->execute($target);
                self::fail('TodoNotFoundException attendue');
            } catch (TodoNotFoundException $e) {
                $messages[] = $e->getMessage();
            }
        }
        self::assertSame($messages[0], $messages[1]);
        self::assertNotNull($this->repo->find('compte-b', $id));
    }
}

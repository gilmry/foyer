<?php

declare(strict_types=1);

namespace TodoApp\Tests\Application;

use PHPUnit\Framework\TestCase;
use TodoApp\Application\Todo\CreateTodo;
use TodoApp\Application\Todo\ListTodos;
use TodoApp\Domain\Account\AuthenticationRequiredException;
use TodoApp\Tests\Fakes\FakeClock;
use TodoApp\Tests\Fakes\FakeCurrentUser;
use TodoApp\Tests\Fakes\FakeIdGenerator;
use TodoApp\Tests\Fakes\FakeTodoRepository;

final class ListTodosTest extends TestCase
{
    /** @negative — liste vide → tableau vide, pas d'erreur */
    public function testEmptyListReturnsEmptyArray(): void
    {
        $uc = new ListTodos(new FakeTodoRepository(), new FakeCurrentUser());
        self::assertSame([], $uc->execute());
    }

    /** @happy + @edge — ordre par date de création, plusieurs tâches */
    public function testListReturnsViewsInCreationOrder(): void
    {
        $repo = new FakeTodoRepository();
        $clock = new FakeClock();
        $user = new FakeCurrentUser();
        $create = new CreateTodo($repo, $clock, new FakeIdGenerator(), $user);

        $create->execute(['title' => 'première']);
        $clock->advance('+1 hour');
        $create->execute(['title' => 'seconde']);

        $items = (new ListTodos($repo, $user))->execute();
        self::assertCount(2, $items);
        self::assertSame('première', $items[0]['title']);
        self::assertSame('seconde', $items[1]['title']);
        self::assertArrayHasKey('done', $items[0]);
        // Le propriétaire ne sort pas dans la vue.
        self::assertSame(['id', 'title', 'done', 'createdAt', 'updatedAt'], array_keys($items[0]));
    }

    /** @happy — cloisonnement : A ne voit que ses tâches */
    public function testListOnlyReturnsCurrentUsersTodos(): void
    {
        $repo = new FakeTodoRepository();
        $ids = new FakeIdGenerator();
        (new CreateTodo($repo, new FakeClock(), $ids, new FakeCurrentUser('compte-a')))->execute(['title' => 'de A']);
        (new CreateTodo($repo, new FakeClock(), $ids, new FakeCurrentUser('compte-b')))->execute(['title' => 'de B']);

        $items = (new ListTodos($repo, new FakeCurrentUser('compte-a')))->execute();
        self::assertSame(['de A'], array_column($items, 'title'));
    }

    /** @edge — la liste est bornée, quelle que soit la demande */
    public function testListIsBounded(): void
    {
        $repo = new FakeTodoRepository();
        $user = new FakeCurrentUser();
        $create = new CreateTodo($repo, new FakeClock(), new FakeIdGenerator(), $user);
        for ($i = 0; $i < ListTodos::MAX_LIMIT + 5; $i++) {
            $create->execute(['title' => "tâche $i"]);
        }
        $uc = new ListTodos($repo, $user);
        self::assertCount(ListTodos::DEFAULT_LIMIT, $uc->execute());
        self::assertCount(ListTodos::MAX_LIMIT, $uc->execute(100000));
        self::assertCount(1, $uc->execute(0));
        self::assertCount(5, $uc->execute(100, ListTodos::MAX_LIMIT));
    }

    /** @negative — sans identité : refus */
    public function testListWithoutIdentityThrows(): void
    {
        $this->expectException(AuthenticationRequiredException::class);
        (new ListTodos(new FakeTodoRepository(), new FakeCurrentUser(null)))->execute();
    }
}

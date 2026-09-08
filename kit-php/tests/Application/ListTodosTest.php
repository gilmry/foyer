<?php

declare(strict_types=1);

namespace TodoApp\Tests\Application;

use PHPUnit\Framework\TestCase;
use TodoApp\Application\Todo\CreateTodo;
use TodoApp\Application\Todo\ListTodos;
use TodoApp\Tests\Fakes\FakeClock;
use TodoApp\Tests\Fakes\FakeIdGenerator;
use TodoApp\Tests\Fakes\FakeTodoRepository;

final class ListTodosTest extends TestCase
{
    /** @negative — liste vide → tableau vide, pas d'erreur */
    public function testEmptyListReturnsEmptyArray(): void
    {
        $uc = new ListTodos(new FakeTodoRepository());
        self::assertSame([], $uc->execute());
    }

    /** @happy + @edge — ordre par date de création, plusieurs tâches */
    public function testListReturnsViewsInCreationOrder(): void
    {
        $repo = new FakeTodoRepository();
        $clock = new FakeClock();
        $ids = new FakeIdGenerator();
        $create = new CreateTodo($repo, $clock, $ids);

        $create->execute(['title' => 'première']);
        $clock->advance('+1 hour');
        $create->execute(['title' => 'seconde']);

        $items = (new ListTodos($repo))->execute();
        self::assertCount(2, $items);
        self::assertSame('première', $items[0]['title']);
        self::assertSame('seconde', $items[1]['title']);
        self::assertArrayHasKey('done', $items[0]);
    }
}

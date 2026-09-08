<?php

declare(strict_types=1);

namespace TodoApp\Tests\Application;

use PHPUnit\Framework\TestCase;
use TodoApp\Application\Todo\CreateTodo;
use TodoApp\Domain\Todo\TodoValidationException;
use TodoApp\Tests\Fakes\FakeClock;
use TodoApp\Tests\Fakes\FakeIdGenerator;
use TodoApp\Tests\Fakes\FakeTodoRepository;

final class CreateTodoTest extends TestCase
{
    private FakeTodoRepository $repo;
    private CreateTodo $uc;

    protected function setUp(): void
    {
        $this->repo = new FakeTodoRepository();
        $this->uc = new CreateTodo($this->repo, new FakeClock(), new FakeIdGenerator());
    }

    /** @happy */
    public function testCreateValidPersistsOpenTodo(): void
    {
        $todo = $this->uc->execute(['title' => '  acheter du pain  ']);
        self::assertSame('gen-1', $todo->id());
        self::assertSame('acheter du pain', $todo->title());
        self::assertFalse($todo->isDone());
        self::assertNotNull($this->repo->find('gen-1'));
    }

    /** @negative — libellé vide → exception, rien de persisté */
    public function testCreateEmptyTitleThrowsAndPersistsNothing(): void
    {
        try {
            $this->uc->execute(['title' => '']);
            self::fail('TodoValidationException attendue');
        } catch (TodoValidationException $e) {
            self::assertNotSame([], $e->errors());
        }
        self::assertSame(0, $this->repo->count());
    }

    /** @security — libellé avec balise stocké verbatim (pas d'exécution) */
    public function testCreateStoresTitleVerbatim(): void
    {
        $todo = $this->uc->execute(['title' => '<b>x</b>']);
        self::assertSame('<b>x</b>', $todo->title());
    }
}

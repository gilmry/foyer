<?php

declare(strict_types=1);

namespace TodoApp\Tests\Unit;

use DateTimeImmutable;
use PHPUnit\Framework\TestCase;
use TodoApp\Domain\Todo\Todo;
use TodoApp\Domain\Todo\TodoValidationException;

final class TodoTest extends TestCase
{
    private function now(): DateTimeImmutable
    {
        return new DateTimeImmutable('2026-01-01T00:00:00+00:00');
    }

    /** @happy */
    public function testConstructValidTodoIsOpen(): void
    {
        $todo = new Todo('id-1', 'acheter du pain', false, $this->now(), $this->now());
        self::assertSame('id-1', $todo->id());
        self::assertSame('acheter du pain', $todo->title());
        self::assertFalse($todo->isDone());
    }

    /** @negative — libellé vide rejeté par le constructeur (invariant) */
    public function testConstructEmptyTitleThrows(): void
    {
        $this->expectException(TodoValidationException::class);
        new Todo('id-1', '   ', false, $this->now(), $this->now());
    }

    /** @edge — bascule idempotente de transition (open→done→open) */
    public function testToggleInvertsStatus(): void
    {
        $todo = new Todo('id-1', 'tâche', false, $this->now(), $this->now());
        $done = $todo->toggled($this->now());
        self::assertTrue($done->isDone());
        self::assertFalse($done->toggled($this->now())->isDone());
        // Immuabilité : l'original reste inchangé.
        self::assertFalse($todo->isDone());
    }

    /** @security — le libellé est une donnée opaque, stocké tel quel (échappement côté rendu) */
    public function testTitleIsStoredVerbatim(): void
    {
        $payload = '<script>alert(1)</script>';
        $todo = new Todo('id-1', $payload, false, $this->now(), $this->now());
        self::assertSame($payload, $todo->title());
        self::assertSame($payload, $todo->toView()['title']);
    }

    /** @happy — vue sérialisée : clés stables */
    public function testToViewShape(): void
    {
        $todo = new Todo('id-1', 'tâche', true, $this->now(), $this->now());
        self::assertSame(
            ['id', 'title', 'done', 'createdAt', 'updatedAt'],
            array_keys($todo->toView()),
        );
        self::assertTrue($todo->toView()['done']);
    }
}

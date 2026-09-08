<?php

declare(strict_types=1);

namespace TodoApp\Tests\Unit;

use PHPUnit\Framework\TestCase;
use TodoApp\Domain\Todo\TodoRules;

final class TodoRulesTest extends TestCase
{
    /** @happy */
    public function testValidTitlePasses(): void
    {
        self::assertSame([], TodoRules::validate(['title' => 'acheter du pain']));
    }

    /** @negative — libellé absent ou vide */
    public function testMissingOrEmptyTitleFails(): void
    {
        self::assertNotSame([], TodoRules::validate([]));
        self::assertNotSame([], TodoRules::validate(['title' => '   ']));
    }

    /** @edge — bornes de longueur */
    public function testTitleAtMaxPassesOverMaxFails(): void
    {
        self::assertSame([], TodoRules::validate(['title' => str_repeat('a', TodoRules::TITLE_MAX)]));
        self::assertNotSame([], TodoRules::validate(['title' => str_repeat('a', TodoRules::TITLE_MAX + 1)]));
    }

    /** @happy — normalisation (trim) */
    public function testNormalizeTrims(): void
    {
        self::assertSame('tâche', TodoRules::normalizeTitle('  tâche  '));
    }
}

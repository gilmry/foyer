<?php

declare(strict_types=1);

namespace TodoApp\Tests\Fakes;

use DateTimeImmutable;
use TodoApp\Domain\Todo\Clock;

/** Horloge figée pour des tests déterministes. */
final class FakeClock implements Clock
{
    public function __construct(private DateTimeImmutable $now = new DateTimeImmutable('2026-01-01T00:00:00+00:00'))
    {
    }

    public function now(): DateTimeImmutable
    {
        return $this->now;
    }

    public function advance(string $modifier): void
    {
        $this->now = $this->now->modify($modifier);
    }
}

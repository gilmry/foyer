<?php

declare(strict_types=1);

namespace TodoApp\Adapter\Todo;

use DateTimeImmutable;
use TodoApp\Domain\Todo\Clock;

/** Horloge réelle (UTC). */
final class RealClock implements Clock
{
    public function now(): DateTimeImmutable
    {
        return new DateTimeImmutable('now');
    }
}

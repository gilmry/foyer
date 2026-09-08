<?php

declare(strict_types=1);

namespace TodoApp\Domain\Todo;

use DateTimeImmutable;

/** Port d'horloge — injecté pour rendre le temps testable (FakeClock en test). */
interface Clock
{
    public function now(): DateTimeImmutable;
}

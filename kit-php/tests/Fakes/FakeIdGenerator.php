<?php

declare(strict_types=1);

namespace TodoApp\Tests\Fakes;

use TodoApp\Domain\Todo\IdGenerator;

/** Génère des IDs séquentiels déterministes (gen-1, gen-2, …). */
final class FakeIdGenerator implements IdGenerator
{
    private int $seq = 0;

    public function uuid(): string
    {
        return 'gen-' . (++$this->seq);
    }
}

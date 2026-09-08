<?php

declare(strict_types=1);

namespace TodoApp\Domain\Todo;

/** Port de génération d'identifiant — injecté pour la testabilité (IDs déterministes en test). */
interface IdGenerator
{
    public function uuid(): string;
}

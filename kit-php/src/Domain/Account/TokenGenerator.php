<?php

declare(strict_types=1);

namespace TodoApp\Domain\Account;

/** Port de tirage des secrets (jetons porteurs, mots de passe tirés) — injecté pour la testabilité. */
interface TokenGenerator
{
    /** Chaîne imprévisible, sûre dans une URL et un en-tête, d'au moins 256 bits d'entropie. */
    public function generate(): string;
}

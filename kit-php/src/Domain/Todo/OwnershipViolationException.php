<?php

declare(strict_types=1);

namespace TodoApp\Domain\Todo;

use LogicException;

/**
 * Levée par un adaptateur quand on lui demande d'écrire une tâche pour un autre propriétaire que
 * le sien. Les cas d'usage ne peuvent pas y arriver ; c'est un garde-fou, pas un cas métier.
 */
final class OwnershipViolationException extends LogicException
{
    public function __construct()
    {
        parent::__construct('Écriture refusée : la tâche n\'appartient pas à ce propriétaire.');
    }
}

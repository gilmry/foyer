<?php

declare(strict_types=1);

namespace TodoApp\Domain\Account;

/**
 * Port d'identité — donne aux cas d'usage l'identifiant du compte courant.
 * Implémenté par chaque adaptateur HTTP (session ou jeton) ; jamais alimenté par la requête.
 */
interface CurrentUser
{
    /** @throws AuthenticationRequiredException quand aucune identité n'est établie */
    public function id(): string;
}

<?php

declare(strict_types=1);

namespace TodoApp\Domain\Account;

/** Règles de validation d'un compte — messages en français. */
final class AccountRules
{
    public const EMAIL_MAX = 190;
    public const PASSWORD_MIN = 12;
    /** Borne haute : celle de Symfony (au-delà, hacher coûte sans rien protéger). */
    public const PASSWORD_MAX = 4096;

    /** @return array<string,string> champ → message (vide si valide) */
    public static function validate(mixed $email, mixed $password): array
    {
        $errors = [];
        $email = is_string($email) ? self::normalizeEmail($email) : '';
        if ($email === '' || mb_strlen($email) > self::EMAIL_MAX || !preg_match('/^[^@\s]+@[^@\s]+\.[^@\s]+$/', $email)) {
            $errors['email'] = 'Le courriel est invalide.';
        }
        if (!is_string($password) || mb_strlen($password) < self::PASSWORD_MIN) {
            $errors['password'] = sprintf('Le mot de passe doit compter au moins %d caractères.', self::PASSWORD_MIN);
        } elseif (strlen($password) > self::PASSWORD_MAX) {
            $errors['password'] = sprintf('Le mot de passe ne peut dépasser %d octets.', self::PASSWORD_MAX);
        }

        return $errors;
    }

    public static function normalizeEmail(string $email): string
    {
        return mb_strtolower(trim($email));
    }
}

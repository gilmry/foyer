<?php

declare(strict_types=1);

namespace TodoApp\Adapter\Account;

use TodoApp\Domain\Account\PasswordHasher;

/**
 * Hacheur sans Composer, AU MÊME FORMAT que le hacheur `auto` de Symfony
 * (Symfony\Component\PasswordHasher\Hasher\NativePasswordHasher) : bcrypt, coût 13, et le même
 * pré-hachage SHA-512 quand le mot de passe dépasse 72 octets ou contient un octet nul.
 * Un compte créé par `bin/account.php` se connecte donc par l'adaptateur API Platform, et
 * inversement. Le gate `integration` vérifie cet aller-retour.
 */
final class NativePasswordHasher implements PasswordHasher
{
    private const COST = 13;
    private const MAX_LENGTH = 4096;

    public function hash(string $plainPassword): string
    {
        if (strlen($plainPassword) > self::MAX_LENGTH) {
            throw new \InvalidArgumentException('Mot de passe trop long.');
        }

        return password_hash(self::prepare($plainPassword), PASSWORD_BCRYPT, ['cost' => self::COST]);
    }

    public function verify(string $hash, string $plainPassword): bool
    {
        if ($plainPassword === '' || strlen($plainPassword) > self::MAX_LENGTH) {
            return false;
        }
        if (!str_starts_with($hash, '$2')) {
            // Autre algorithme natif (argon2…) : password_verify le reconnaît à son préfixe.
            return password_verify($plainPassword, $hash);
        }

        return password_verify(self::prepare($plainPassword), $hash);
    }

    /** bcrypt tronque à 72 octets et s'arrête au premier octet nul : même parade que Symfony. */
    private static function prepare(string $plainPassword): string
    {
        if (strlen($plainPassword) > 72 || str_contains($plainPassword, "\0")) {
            return base64_encode(hash('sha512', $plainPassword, true));
        }

        return $plainPassword;
    }
}

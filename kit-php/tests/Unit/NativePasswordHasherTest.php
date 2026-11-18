<?php

declare(strict_types=1);

namespace TodoApp\Tests\Unit;

use PHPUnit\Framework\TestCase;
use TodoApp\Adapter\Account\NativePasswordHasher;

final class NativePasswordHasherTest extends TestCase
{
    /** @security — hachage salé, vérifiable, jamais le clair */
    public function testHashVerifies(): void
    {
        $hasher = new NativePasswordHasher();
        $hash = $hasher->hash('un-mot-de-passe-long');
        self::assertStringStartsWith('$2y$13$', $hash);
        self::assertStringNotContainsString('un-mot-de-passe-long', $hash);
        self::assertNotSame($hash, $hasher->hash('un-mot-de-passe-long'));
        self::assertTrue($hasher->verify($hash, 'un-mot-de-passe-long'));
        self::assertFalse($hasher->verify($hash, 'un-mot-de-passe-lonG'));
        self::assertFalse($hasher->verify($hash, ''));
    }

    /** @edge — au-delà de 72 octets, bcrypt tronquerait : le pré-hachage distingue encore */
    public function testLongPasswordsAreNotTruncated(): void
    {
        $hasher = new NativePasswordHasher();
        $long = str_repeat('a', 80);
        $hash = $hasher->hash($long);
        self::assertTrue($hasher->verify($hash, $long));
        self::assertFalse($hasher->verify($hash, str_repeat('a', 79) . 'b'));
    }
}

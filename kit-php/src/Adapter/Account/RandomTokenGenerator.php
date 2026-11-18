<?php

declare(strict_types=1);

namespace TodoApp\Adapter\Account;

use TodoApp\Domain\Account\TokenGenerator;

/** 32 octets du générateur du système, en base64 « URL ». */
final class RandomTokenGenerator implements TokenGenerator
{
    public function generate(): string
    {
        return rtrim(strtr(base64_encode(random_bytes(32)), '+/', '-_'), '=');
    }
}

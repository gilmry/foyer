<?php

declare(strict_types=1);

namespace TodoApp\Application\Account;

use DateTimeImmutable;
use TodoApp\Domain\Account\AccessTokenRepository;
use TodoApp\Domain\Account\TokenGenerator;
use TodoApp\Domain\Todo\Clock;

/**
 * Cas d'usage : émettre un jeton porteur pour un compte déjà authentifié.
 * Le jeton en clair n'existe que dans la valeur de retour ; seule son empreinte est persistée.
 */
final class IssueAccessToken
{
    public const PREFIX = 'kit_';
    public const TTL = 'P30D';

    public function __construct(
        private readonly AccessTokenRepository $tokens,
        private readonly TokenGenerator $generator,
        private readonly Clock $clock,
    ) {
    }

    /** @return array{token:string,expiresAt:DateTimeImmutable} */
    public function execute(string $accountId): array
    {
        $now = $this->clock->now();
        $expiresAt = $now->add(new \DateInterval(self::TTL));
        $token = self::PREFIX . $this->generator->generate();
        $this->tokens->removeExpired($now);
        $this->tokens->add(self::fingerprint($token), $accountId, $now, $expiresAt);

        return ['token' => $token, 'expiresAt' => $expiresAt];
    }

    /** Empreinte SHA-256 : le jeton a 256 bits d'entropie, un hachage lent ne protégerait rien de plus. */
    public static function fingerprint(string $token): string
    {
        return hash('sha256', $token);
    }
}

<?php

declare(strict_types=1);

namespace TodoApp\Http\ApiPlatform\Security;

use Symfony\Component\HttpFoundation\RateLimiter\PeekableRequestRateLimiterInterface;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\RateLimiter\RateLimit;
use Symfony\Component\Security\Http\SecurityRequestAttributes;
use TodoApp\Adapter\Services;
use TodoApp\Domain\Account\AccountRules;

/**
 * Limiteur des essais de connexion, branché sur `login_throttling` des DEUX pare-feu à mot de
 * passe (`main` et `token_issue`) : un seul compteur, quel que soit le point d'entrée.
 *
 * Il remplace le limiteur par défaut de Symfony, dont la clé est l'identifiant tel que saisi
 * (« a@x.fr », « a@x.fr » précédé d'une espace et « A@x.fr » avaient chacun leur compteur pour le
 * même compte), qui tient un compteur par pare-feu, et qui ne compte l'essai qu'APRÈS l'échec
 * (N requêtes simultanées passaient toutes). Ici :
 *  - la clé du compte est le courriel NORMALISÉ, celui-là même qui sert à chercher le compte ;
 *  - le plafond par compte ne dépend pas de l'adresse IP (5 essais par minute) ;
 *  - un plafond par adresse IP borne le nombre de comptes essayés (clé `login_ip_limit`) ;
 *  - l'essai est RÉSERVÉ, sous verrou de la base (table `attempt_windows`), AVANT la vérification
 *    du mot de passe.
 * Une connexion réussie remet le compteur du compte à zéro et rend l'essai à l'adresse.
 */
final class LoginLimiter implements PeekableRequestRateLimiterInterface
{
    public const ACCOUNT_LIMIT = 5;
    public const WINDOW = 60;

    public function __construct(private readonly Services $services)
    {
    }

    /** Appelé par Symfony avant la vérification du mot de passe : c'est ici que l'essai est réservé. */
    public function peek(Request $request): RateLimit
    {
        $ipLimit = (int) $this->services->config()['login_ip_limit'];
        if ($ipLimit > 0) {
            $ip = $this->services->attempts()->reserve($this->ipKey($request), $ipLimit, self::WINDOW);
            if (!$ip['accepted']) {
                return $this->refused($ip['retryAfter']);
            }
        }
        $account = $this->services->attempts()->reserve($this->accountKey($request), self::ACCOUNT_LIMIT, self::WINDOW);
        if (!$account['accepted']) {
            if ($ipLimit > 0) {
                $this->services->attempts()->release($this->ipKey($request));
            }

            return $this->refused($account['retryAfter']);
        }

        // Symfony lit ce résultat comme un état « avant l'essai » : il refuse s'il reste 0 jeton et
        // n'appelle reset() au succès que si le compteur a été entamé. On lui rend donc ce qui
        // restait avant la réservation, sur une limite décalée de un, pour que reset() soit
        // toujours appelé au succès.
        return new RateLimit(self::ACCOUNT_LIMIT - $account['used'], new \DateTimeImmutable('@' . $account['retryAfter']), true, self::ACCOUNT_LIMIT + 1);
    }

    /** Appelé après un échec : l'essai est déjà compté, il n'y a rien à ajouter. */
    public function consume(Request $request): RateLimit
    {
        return new RateLimit(0, new \DateTimeImmutable('+' . self::WINDOW . ' seconds'), true, self::ACCOUNT_LIMIT + 1);
    }

    /** Appelé après une connexion réussie. */
    public function reset(Request $request): void
    {
        $this->services->attempts()->reset($this->accountKey($request));
        if ((int) $this->services->config()['login_ip_limit'] > 0) {
            $this->services->attempts()->release($this->ipKey($request));
        }
    }

    private function refused(int $retryAfter): RateLimit
    {
        return new RateLimit(0, new \DateTimeImmutable('@' . max($retryAfter, time() + 1)), false, self::ACCOUNT_LIMIT + 1);
    }

    private function accountKey(Request $request): string
    {
        $identifier = $request->attributes->get(SecurityRequestAttributes::LAST_USERNAME, '');

        return 'compte:' . AccountRules::normalizeEmail(is_string($identifier) ? $identifier : '');
    }

    private function ipKey(Request $request): string
    {
        return 'adresse:' . (string) $request->getClientIp();
    }
}

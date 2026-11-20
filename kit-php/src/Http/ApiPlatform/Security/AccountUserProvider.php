<?php

declare(strict_types=1);

namespace TodoApp\Http\ApiPlatform\Security;

use Symfony\Component\Security\Core\Exception\UnsupportedUserException;
use Symfony\Component\Security\Core\Exception\UserNotFoundException;
use Symfony\Component\Security\Core\User\UserInterface;
use Symfony\Component\Security\Core\User\UserProviderInterface;
use TodoApp\Domain\Account\AccountRepository;
use TodoApp\Domain\Account\AccountRules;

/**
 * Charge les comptes pour le composant de sécurité, par le port AccountRepository.
 *
 * @implements UserProviderInterface<SecurityUser>
 */
final class AccountUserProvider implements UserProviderInterface
{
    public function __construct(private readonly AccountRepository $accounts)
    {
    }

    /**
     * Hachage bcrypt (coût 13) d'une valeur aléatoire jetée aussitôt : aucun mot de passe n'y
     * correspond. Il sert de LEURRE pour un courriel inconnu.
     */
    private const DECOY_HASH = '$2y$13$S3SJCK19dv1mEAXRYn.37O4EVQMTg/h4I6gbehYUHZM6euQleeEY6';

    public function loadUserByIdentifier(string $identifier): UserInterface
    {
        $account = $this->accounts->findByEmail(AccountRules::normalizeEmail($identifier));
        if ($account === null) {
            // Compte inconnu : on rend un leurre plutôt que de lever UserNotFoundException. Le mot
            // de passe est alors vérifié (et refusé) contre un vrai hachage : même réponse ET même
            // temps de calcul que pour un mauvais mot de passe — le délai ne dit pas si le compte existe.
            return new SecurityUser('', AccountRules::normalizeEmail($identifier), self::DECOY_HASH);
        }

        return SecurityUser::fromAccount($account);
    }

    public function loadById(string $accountId): SecurityUser
    {
        $account = $this->accounts->findById($accountId);
        if ($account === null) {
            throw new UserNotFoundException();
        }

        return SecurityUser::fromAccount($account);
    }

    /** À chaque requête de session : le compte existe-t-il encore, le hachage est-il le même ? */
    public function refreshUser(UserInterface $user): UserInterface
    {
        if (!$user instanceof SecurityUser) {
            throw new UnsupportedUserException();
        }

        return $this->loadById($user->id);
    }

    public function supportsClass(string $class): bool
    {
        return $class === SecurityUser::class;
    }
}

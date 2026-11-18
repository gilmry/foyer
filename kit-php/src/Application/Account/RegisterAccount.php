<?php

declare(strict_types=1);

namespace TodoApp\Application\Account;

use TodoApp\Domain\Account\Account;
use TodoApp\Domain\Account\AccountRepository;
use TodoApp\Domain\Account\AccountRules;
use TodoApp\Domain\Account\AccountValidationException;
use TodoApp\Domain\Account\EmailAlreadyUsedException;
use TodoApp\Domain\Account\PasswordHasher;
use TodoApp\Domain\Todo\Clock;
use TodoApp\Domain\Todo\IdGenerator;

/** Cas d'usage : créer un compte. Seul le hachage du mot de passe est persisté. */
final class RegisterAccount
{
    public function __construct(
        private readonly AccountRepository $accounts,
        private readonly PasswordHasher $hasher,
        private readonly Clock $clock,
        private readonly IdGenerator $ids,
    ) {
    }

    /**
     * @throws AccountValidationException
     * @throws EmailAlreadyUsedException
     */
    public function execute(mixed $email, mixed $password): Account
    {
        $errors = AccountRules::validate($email, $password);
        if ($errors !== []) {
            throw new AccountValidationException($errors);
        }
        $email = AccountRules::normalizeEmail((string) $email);
        // Le hachage est calculé AVANT de regarder si le courriel est pris : le temps de réponse
        // est le même dans les deux cas et ne dit pas si un compte existe.
        $hash = $this->hasher->hash((string) $password);
        if ($this->accounts->findByEmail($email) !== null) {
            throw new EmailAlreadyUsedException();
        }

        $account = new Account($this->ids->uuid(), $email, $hash, $this->clock->now());
        $this->accounts->add($account);

        return $account;
    }
}

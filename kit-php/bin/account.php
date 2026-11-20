#!/usr/bin/env php
<?php

declare(strict_types=1);

/**
 * Comptes en ligne de commande : php bin/account.php create|token <courriel>
 *
 *   create <courriel>   crée un compte. Le mot de passe est lu sur l'entrée standard (une ligne)
 *                       quand elle n'est pas un terminal ; sinon il est tiré et affiché UNE fois.
 *   token <courriel>    émet un jeton porteur pour ce compte et l'affiche UNE fois.
 *
 * Le mot de passe et le jeton ne passent jamais en argument (ils resteraient dans l'historique et
 * la liste des processus). Sans Composer : même format de hachage que l'adaptateur API Platform.
 */
use TodoApp\Adapter\Services;
use TodoApp\Application\Account\IssueAccessToken;
use TodoApp\Application\Account\RegisterAccount;
use TodoApp\Config;
use TodoApp\Domain\Account\AccountRules;
use TodoApp\Domain\Account\AccountValidationException;
use TodoApp\Domain\Account\EmailAlreadyUsedException;

require dirname(__DIR__) . '/src/bootstrap.php';

[$command, $email] = [$argv[1] ?? '', $argv[2] ?? ''];
if (!in_array($command, ['create', 'token'], true) || $email === '' || isset($argv[3])) {
    fwrite(STDERR, "usage : php bin/account.php create|token <courriel>\n");
    exit(2);
}

try {
    $services = new Services(Config::load());

    if ($command === 'create') {
        $generated = false;
        if (stream_isatty(STDIN)) {
            $password = $services->tokenGenerator()->generate();
            $generated = true;
        } else {
            $password = rtrim((string) fgets(STDIN), "\r\n");
        }
        $account = (new RegisterAccount($services->accounts(), $services->hasher(), $services->clock(), $services->ids()))
            ->execute($email, $password);
        echo 'compte créé : ' . $account->email() . "\n";
        if ($generated) {
            echo "mot de passe (affiché une seule fois) : $password\n";
        }
        exit(0);
    }

    $account = $services->accounts()->findByEmail(AccountRules::normalizeEmail($email));
    if ($account === null) {
        fwrite(STDERR, "compte inconnu\n");
        exit(1);
    }
    $issued = (new IssueAccessToken($services->tokens(), $services->tokenGenerator(), $services->clock()))->execute($account->id());
    // Le jeton seul sur la sortie standard, pour être capté par un script sans passer à l'écran.
    fwrite(STDERR, 'jeton émis, valable jusqu\'au ' . $issued['expiresAt']->format('Y-m-d') . " (affiché une seule fois) :\n");
    echo $issued['token'] . "\n";
    exit(0);
} catch (AccountValidationException $e) {
    fwrite(STDERR, implode("\n", $e->errors()) . "\n");
    exit(1);
} catch (EmailAlreadyUsedException $e) {
    fwrite(STDERR, $e->getMessage() . "\n");
    exit(1);
} catch (PDOException $e) {
    fwrite(STDERR, 'échec de base de données (SQLSTATE ' . $e->getCode() . ").\n");
    exit(1);
} catch (Throwable $e) {
    fwrite(STDERR, 'échec : ' . $e->getMessage() . "\n");
    exit(1);
}

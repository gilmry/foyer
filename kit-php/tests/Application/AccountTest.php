<?php

declare(strict_types=1);

namespace TodoApp\Tests\Application;

use PHPUnit\Framework\TestCase;
use TodoApp\Application\Account\IssueAccessToken;
use TodoApp\Application\Account\RegisterAccount;
use TodoApp\Application\Account\ResolveAccessToken;
use TodoApp\Application\Account\RevokeAccessToken;
use TodoApp\Domain\Account\AccountValidationException;
use TodoApp\Domain\Account\EmailAlreadyUsedException;
use TodoApp\Tests\Fakes\FakeAccountStore;
use TodoApp\Tests\Fakes\FakeClock;
use TodoApp\Tests\Fakes\FakeIdGenerator;
use TodoApp\Tests\Fakes\FakeTokenStore;

final class AccountTest extends TestCase
{
    private FakeAccountStore $store;
    private FakeClock $clock;
    private RegisterAccount $register;

    protected function setUp(): void
    {
        $this->store = new FakeAccountStore();
        $this->clock = new FakeClock();
        $this->register = new RegisterAccount($this->store, $this->store, $this->clock, new FakeIdGenerator());
    }

    /** @security — seul un hachage est persisté ; la vue ne le porte pas */
    public function testRegisterStoresOnlyAHash(): void
    {
        $account = $this->register->execute('  Alice@Exemple.test ', 'un-mot-de-passe-long');
        self::assertSame('alice@exemple.test', $account->email());
        self::assertNotSame('un-mot-de-passe-long', $account->passwordHash());
        self::assertStringNotContainsString('un-mot-de-passe-long', serialize($this->store->accounts));
        self::assertSame(['id', 'email'], array_keys($account->toView()));
    }

    /** @negative — courriel invalide, mot de passe trop court, types inattendus */
    public function testRegisterRejectsInvalidInput(): void
    {
        foreach ([['pas-un-courriel', 'un-mot-de-passe-long'], ['a@b.test', 'court'], [null, null], [['x'], 12]] as [$email, $password]) {
            try {
                $this->register->execute($email, $password);
                self::fail('AccountValidationException attendue');
            } catch (AccountValidationException $e) {
                self::assertNotSame([], $e->errors());
            }
        }
        self::assertSame([], $this->store->accounts);
    }

    /** @negative — un courriel, un compte (insensible à la casse) */
    public function testRegisterRejectsDuplicateEmail(): void
    {
        $this->register->execute('alice@exemple.test', 'un-mot-de-passe-long');
        $this->expectException(EmailAlreadyUsedException::class);
        $this->register->execute('ALICE@exemple.test', 'un-autre-mot-de-passe');
    }

    /** @security — le jeton en clair n'est jamais persisté ; il se résout, échoit et se révoque */
    public function testTokenLifecycle(): void
    {
        $tokens = new FakeTokenStore();
        $account = $this->register->execute('alice@exemple.test', 'un-mot-de-passe-long');
        $issued = (new IssueAccessToken($tokens, $this->store, $this->clock))->execute($account->id());
        $token = $issued['token'];

        self::assertStringStartsWith(IssueAccessToken::PREFIX, $token);
        self::assertStringNotContainsString($token, serialize($tokens->tokens));
        self::assertArrayHasKey(hash('sha256', $token), $tokens->tokens);

        $resolve = new ResolveAccessToken($tokens, $this->clock);
        self::assertSame($account->id(), $resolve->execute($token));
        self::assertNull($resolve->execute($token . 'x'));
        self::assertNull($resolve->execute('pas-un-jeton'));

        // Échéance.
        $this->clock->advance('+31 days');
        self::assertNull($resolve->execute($token));

        // Révocation.
        $fresh = (new IssueAccessToken($tokens, $this->store, $this->clock))->execute($account->id())['token'];
        self::assertSame($account->id(), $resolve->execute($fresh));
        (new RevokeAccessToken($tokens))->execute($fresh);
        self::assertNull($resolve->execute($fresh));
    }
}

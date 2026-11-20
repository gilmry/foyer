<?php

declare(strict_types=1);

/**
 * Gate `integration` — contre une base réelle (MySQL 8 du harnais, ou la MariaDB de la répétition
 * de déploiement), avec le LOGIN APPLICATIF SANS PRIVILÈGE :
 *
 *  1. le login courant n'a aucun privilège global (sinon le gate échoue : un superutilisateur
 *     masquerait ce que l'application doit à ses droits) ;
 *  2. l'outil de migration : applique, ne rejoue rien, annule, refuse une migration modifiée ;
 *  3. les DEUX adaptateurs de persistance (CQRS SQL pur ET Doctrine ORM), par les cas d'usage :
 *     parcours de référence, puis cloisonnement par propriétaire ;
 *  4. comptes et jetons : seuls des hachages en base ; le hacheur du kit et celui de Symfony
 *     (`auto`) se vérifient l'un l'autre.
 */
require __DIR__ . '/../src/bootstrap.php';
$vendor = __DIR__ . '/../vendor/autoload.php';
if (is_file($vendor)) {
    require_once $vendor;
}

use Symfony\Component\PasswordHasher\Hasher\PasswordHasherFactory;
use TodoApp\Adapter\Account\FixedCurrentUser;
use TodoApp\Adapter\Account\NativePasswordHasher;
use TodoApp\Adapter\Account\PdoAccessTokenRepository;
use TodoApp\Adapter\Account\PdoAccountRepository;
use TodoApp\Adapter\Account\RandomTokenGenerator;
use TodoApp\Adapter\Migration\Migrator;
use TodoApp\Adapter\Todo\CqrsTodoRepository;
use TodoApp\Adapter\Todo\Doctrine\EntityManagerFactory;
use TodoApp\Adapter\Todo\DoctrineTodoRepository;
use TodoApp\Adapter\Todo\RealClock;
use TodoApp\Adapter\Todo\UuidGenerator;
use TodoApp\Application\Account\IssueAccessToken;
use TodoApp\Application\Account\RegisterAccount;
use TodoApp\Application\Account\ResolveAccessToken;
use TodoApp\Application\Account\RevokeAccessToken;
use TodoApp\Application\Todo\CreateTodo;
use TodoApp\Application\Todo\DeleteTodo;
use TodoApp\Application\Todo\GetTodo;
use TodoApp\Application\Todo\ListTodos;
use TodoApp\Application\Todo\ToggleTodo;
use TodoApp\Config;
use TodoApp\Database;
use TodoApp\Domain\Account\AuthenticationRequiredException;
use TodoApp\Domain\Account\EmailAlreadyUsedException;
use TodoApp\Domain\Todo\OwnershipViolationException;
use TodoApp\Domain\Todo\TodoNotFoundException;
use TodoApp\Domain\Todo\TodoRepository;

$config = Config::load();
$migrations = __DIR__ . '/../database/migrations/pending';

$assertions = 0;
$failures = 0;
function check(string $label, bool $cond): void
{
    global $assertions, $failures;
    $assertions++;
    if ($cond) {
        fwrite(STDOUT, "  ✓ $label\n");
    } else {
        $failures++;
        fwrite(STDOUT, "  ✗ $label\n");
    }
}

/** Vrai si l'appel lève une exception de la classe attendue. */
function throws(string $class, callable $fn): bool
{
    try {
        $fn();
    } catch (Throwable $e) {
        return $e instanceof $class;
    }

    return false;
}

function drop_all(PDO $db): void
{
    $db->exec('SET FOREIGN_KEY_CHECKS = 0');
    foreach ($db->query('SHOW TABLES')->fetchAll(PDO::FETCH_COLUMN) as $table) {
        $db->exec('DROP TABLE `' . str_replace('`', '``', (string) $table) . '`');
    }
    $db->exec('SET FOREIGN_KEY_CHECKS = 1');
}

$db = Database::connect($config);

// ---------------------------------------------------------------------------------------------
fwrite(STDOUT, "\n[login sans privilège]\n");
$version = (string) $db->query('SELECT VERSION()')->fetchColumn();
$user = (string) $db->query('SELECT CURRENT_USER()')->fetchColumn();
fwrite(STDOUT, "  · serveur : $version ; login : " . preg_replace('/@.*/', '', $user) . "\n");
$grants = $db->query('SHOW GRANTS FOR CURRENT_USER()')->fetchAll(PDO::FETCH_COLUMN);
$global = array_filter($grants, static fn ($g): bool => (bool) preg_match('/\bON \*\.\* /i', (string) $g) && !preg_match('/^GRANT USAGE ON \*\.\* /i', (string) $g));
check('le login courant n\'a aucun privilège global (seulement USAGE sur *.*)', $global === []);
check('le login courant n\'a pas GRANT OPTION', array_filter($grants, static fn ($g): bool => stripos((string) $g, 'WITH GRANT OPTION') !== false) === []);
check('le login courant n\'est pas root', !str_starts_with(strtolower($user), 'root@'));
check('le login courant ne peut pas créer d\'utilisateur', throws(PDOException::class, static fn () => $db->exec("CREATE USER 'kit_intrus'@'localhost'")));

// ---------------------------------------------------------------------------------------------
fwrite(STDOUT, "\n[outil de migration]\n");
drop_all($db);
$migrator = new Migrator($db, $migrations);
$first = $migrator->up();
check('up sur base vide : toutes les migrations passent, dans l\'ordre', $first === ['0001_create_todos', '0002_accounts_and_owner', '0003_attempt_windows']);
check('up rejoué : aucune migration rejouée', $migrator->up() === []);
check('les migrations passées sont tracées avec leur somme de contrôle', (int) $db->query("SELECT COUNT(*) FROM schema_migrations WHERE checksum REGEXP '^[0-9a-f]{64}$'")->fetchColumn() === 3);
check('down : annule la dernière (0003), puis la précédente (0002)', $migrator->down() === '0003_attempt_windows' && $migrator->down() === '0002_accounts_and_owner');
$columns = $db->query('SHOW COLUMNS FROM todos')->fetchAll(PDO::FETCH_COLUMN);
$tables = $db->query('SHOW TABLES')->fetchAll(PDO::FETCH_COLUMN);
check('down : la colonne propriétaire et les tables de comptes ont disparu', !in_array('owner_id', $columns, true) && !in_array('accounts', $tables, true) && !in_array('access_tokens', $tables, true) && !in_array('attempt_windows', $tables, true));
check('up après down : les seules migrations annulées repassent (réversibles)', $migrator->up() === ['0002_accounts_and_owner', '0003_attempt_windows']);

$copy = sys_get_temp_dir() . '/kit-migrations-' . bin2hex(random_bytes(4));
mkdir($copy);
foreach (glob($migrations . '/*.sql') ?: [] as $file) {
    copy($file, $copy . '/' . basename($file));
}
file_put_contents($copy . '/0001_create_todos.up.sql', "\n-- modifiée après coup\n", FILE_APPEND);
$tampered = new Migrator($db, $copy);
check('une migration déjà passée puis MODIFIÉE : up refuse', throws(RuntimeException::class, static fn () => $tampered->up()));
check('… et status la signale', in_array('modified', array_column($tampered->status(), 'state'), true));
unlink($copy . '/0003_attempt_windows.up.sql');
check('une migration passée dont le fichier a disparu : up refuse', throws(RuntimeException::class, static fn () => (new Migrator($db, $copy))->up()));
array_map('unlink', glob($copy . '/*') ?: []);
rmdir($copy);
check('une instruction SQL fausse en milieu de fichier fait échouer la migration', throws(PDOException::class, static function () use ($db): void {
    foreach (Migrator::statements("SET @kit = 1;\nDROP TABLE table_qui_n_existe_pas;\nSET @kit = 2;\n") as $s) {
        $db->exec($s);
    }
}));

// ---------------------------------------------------------------------------------------------
fwrite(STDOUT, "\n[comptes et jetons]\n");
$clock = new RealClock();
$ids = new UuidGenerator();
$accounts = new PdoAccountRepository($db);
$tokens = new PdoAccessTokenRepository($db);
$native = new NativePasswordHasher();
$register = new RegisterAccount($accounts, $native, $clock, $ids);

$passwordA = 'mot-de-passe-' . bin2hex(random_bytes(8));
$a = $register->execute('Alice@Exemple.test', $passwordA);
$b = $register->execute('bob@exemple.test', 'mot-de-passe-' . bin2hex(random_bytes(8)));
$row = $db->query("SELECT * FROM accounts WHERE email = 'alice@exemple.test'")->fetch();
check('le compte est stocké avec un hachage bcrypt, jamais le mot de passe', is_array($row) && str_starts_with((string) $row['password_hash'], '$2y$13$') && !str_contains(json_encode($row), $passwordA));
check('le courriel se compare octet pour octet : une variante accentuée ne désigne PAS le compte', $accounts->findByEmail('álice@exemple.test') === null && $accounts->findByEmail('alicé@exemple.test') === null && $accounts->findByEmail('alice@exemple.test') !== null);
check('… ni en SQL (collation binaire de la colonne)', (int) $db->query("SELECT COUNT(*) FROM accounts WHERE email = 'álice@exemple.test' OR email = 'ALICE@exemple.test'")->fetchColumn() === 0);
$limiter = new TodoApp\Adapter\Account\PdoAttemptLimiter($db);
$accepted = 0;
for ($i = 0; $i < 8; $i++) {
    $accepted += $limiter->reserve('clé', 5, 60)['accepted'] ? 1 : 0;
}
$limiter->reset('clé');
check('compteur d\'essais en base : 5 réservations acceptées sur 8, puis remise à zéro', $accepted === 5 && $limiter->reserve('clé', 5, 60)['accepted']);
check('… la clé n\'y figure qu\'en empreinte', (int) $db->query("SELECT COUNT(*) FROM attempt_windows WHERE key_hash NOT REGEXP '^[0-9a-f]{64}$'")->fetchColumn() === 0);
check('un courriel, un compte : le doublon est refusé', throws(EmailAlreadyUsedException::class, static fn () => $register->execute('ALICE@exemple.test', 'un-autre-mot-de-passe')));

if (class_exists(PasswordHasherFactory::class)) {
    $symfony = (new PasswordHasherFactory(['kit' => ['algorithm' => 'auto']]))->getPasswordHasher('kit');
    check('le hacheur `auto` de Symfony vérifie un hachage du kit (compte créé par bin/account.php)', $symfony->verify((string) $row['password_hash'], $passwordA));
    check('… et refuse un autre mot de passe', !$symfony->verify((string) $row['password_hash'], $passwordA . 'x'));
    check('le hacheur du kit vérifie un hachage de Symfony (compte créé par l\'API)', $native->verify($symfony->hash($passwordA), $passwordA));
    $long = str_repeat('é', 60);
    check('même pré-hachage au-delà de 72 octets, dans les deux sens', $symfony->verify($native->hash($long), $long) && $native->verify($symfony->hash($long), $long));
} else {
    check('vendor/ présent pour vérifier la compatibilité avec le hacheur de Symfony', false);
}

$issued = (new IssueAccessToken($tokens, new RandomTokenGenerator(), $clock))->execute($a->id());
$resolve = new ResolveAccessToken($tokens, $clock);
$stored = $db->query('SELECT * FROM access_tokens')->fetchAll();
check('le jeton est stocké en empreinte SHA-256, jamais en clair', count($stored) === 1 && $stored[0]['token_hash'] === hash('sha256', $issued['token']) && !str_contains(json_encode($stored), $issued['token']));
check('le jeton se résout vers son compte', $resolve->execute($issued['token']) === $a->id());
check('un jeton inconnu ne se résout pas', $resolve->execute('kit_' . bin2hex(random_bytes(16))) === null);
$db->exec("UPDATE access_tokens SET expires_at = '2000-01-01 00:00:00'");
check('un jeton échu ne se résout plus', $resolve->execute($issued['token']) === null);
$fresh = (new IssueAccessToken($tokens, new RandomTokenGenerator(), $clock))->execute($a->id())['token'];
check('émettre un jeton purge les jetons échus', (int) $db->query('SELECT COUNT(*) FROM access_tokens')->fetchColumn() === 1);
(new RevokeAccessToken($tokens))->execute($fresh);
check('un jeton révoqué ne se résout plus', $resolve->execute($fresh) === null);

// ---------------------------------------------------------------------------------------------
/** @param callable():TodoRepository $repoFactory */
function run(string $kind, PDO $db, callable $repoFactory, string $ownerA, string $ownerB): void
{
    fwrite(STDOUT, "\n[$kind]\n");
    $db->exec('DELETE FROM todos');
    $clock = new RealClock();
    $ids = new UuidGenerator();
    $userA = new FixedCurrentUser($ownerA);
    $userB = new FixedCurrentUser($ownerB);

    // Parcours de référence, pour A.
    $repo = $repoFactory();
    $todo = (new CreateTodo($repo, $clock, $ids, $userA))->execute(['title' => 'acheter du pain']);
    check("$kind: create persiste et relit", $repo->find($ownerA, $todo->id()) !== null);
    check("$kind: statut initial « à faire »", $repo->find($ownerA, $todo->id())->isDone() === false);
    $items = (new ListTodos($repo, $userA))->execute();
    check("$kind: list = 1 élément, bon libellé", count($items) === 1 && $items[0]['title'] === 'acheter du pain');
    (new ToggleTodo($repo, $clock, $userA))->execute($todo->id());
    check("$kind: toggle persisté (faite)", $repo->find($ownerA, $todo->id())->isDone() === true);

    // Nouvelle instance d'adaptateur : l'état survit (persistance réelle).
    $repo2 = $repoFactory();
    $found = $repo2->findAll($ownerA, 100);
    check("$kind: persistance inter-instance", count($found) === 1 && $found[0]->isDone() === true && $found[0]->ownerId() === $ownerA);

    // Cloisonnement par propriétaire (issue #31), sur CET adaptateur.
    $ofB = (new CreateTodo($repo2, $clock, $ids, $userB))->execute(['title' => 'tâche de B']);
    $listA = array_column((new ListTodos($repo2, $userA))->execute(), 'id');
    $listB = array_column((new ListTodos($repo2, $userB))->execute(), 'id');
    check("$kind: @happy A liste son todo et pas celui de B", $listA === [$todo->id()] && $listB === [$ofB->id()]);
    check("$kind: @edge find du todo de B par A → null (comme un identifiant inexistant)", $repo2->find($ownerA, $ofB->id()) === null && $repo2->find($ownerA, 'inexistant') === null);
    check("$kind: @edge A lit le todo de B → introuvable", throws(TodoNotFoundException::class, static fn () => (new GetTodo($repo2, $userA))->execute($ofB->id())));
    check("$kind: @edge A bascule le todo de B → introuvable", throws(TodoNotFoundException::class, static fn () => (new ToggleTodo($repo2, new RealClock(), $userA))->execute($ofB->id())));
    check("$kind: @edge A supprime le todo de B → introuvable", throws(TodoNotFoundException::class, static fn () => (new DeleteTodo($repo2, $userA))->execute($ofB->id())));
    $repo2->delete($ownerA, $ofB->id());
    $still = $repoFactory()->find($ownerB, $ofB->id());
    check("$kind: le todo de B est intact (ni basculé, ni supprimé, même par le port)", $still !== null && $still->isDone() === false);
    check("$kind: écrire le todo de B au nom de A est refusé par l'adaptateur", throws(OwnershipViolationException::class, static fn () => $repo2->save($ownerA, $still->toggled(new DateTimeImmutable()))));
    $stolen = new TodoApp\Domain\Todo\Todo($ofB->id(), $ownerA, 'détournée', true, new DateTimeImmutable(), new DateTimeImmutable());
    check("$kind: réécrire l'identifiant d'un todo de B sous le nom de A est refusé", throws(OwnershipViolationException::class, static fn () => $repo2->save($ownerA, $stolen)));
    check("$kind: @security un champ propriétaire dans l'entrée est ignoré", (new CreateTodo($repo2, $clock, $ids, $userA))->execute(['title' => 'x', 'ownerId' => $ownerB, 'owner_id' => $ownerB])->ownerId() === $ownerA);
    check("$kind: @negative sans identité, aucun cas d'usage ne s'exécute", throws(AuthenticationRequiredException::class, static fn () => (new ListTodos($repo2, new FixedCurrentUser(null)))->execute())
        && throws(AuthenticationRequiredException::class, static fn () => (new CreateTodo($repo2, new RealClock(), new UuidGenerator(), new FixedCurrentUser(null)))->execute(['title' => 'intrus'])));
    check("$kind: liste bornée (limit, offset)", count($repo2->findAll($ownerA, 1)) === 1 && count($repo2->findAll($ownerA, 100, 1)) === 1);

    (new DeleteTodo($repo2, $userA))->execute($todo->id());
    check("$kind: delete → absent de la liste de A, B inchangé", !in_array($todo->id(), array_column((new ListTodos($repo2, $userA))->execute(), 'id'), true) && count((new ListTodos($repo2, $userB))->execute()) === 1);
}

run('cqrs', $db, static fn (): TodoRepository => new CqrsTodoRepository(Database::connect($config)), $a->id(), $b->id());
run('doctrine', $db, static fn (): TodoRepository => new DoctrineTodoRepository(EntityManagerFactory::create($config)), $a->id(), $b->id());

fwrite(STDOUT, sprintf("\nintegration: %s (%d assertions, %d échecs)\n", $failures === 0 ? '🟢' : '🔴', $assertions, $failures));
exit($failures === 0 ? 0 : 1);

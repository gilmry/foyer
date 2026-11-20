<?php

declare(strict_types=1);

/**
 * Gate `verify` / `plancher` — invariants structurels (exit 0 = 🟢, ≠0 = 🔴).
 * Exécuté via Docker : bash harness/run-verify.sh (ou docker run … php harness/verify.php).
 * Checks : G1 (secrets hors dépôt, secret du noyau fourni par configuration),
 *          G2 (migrations réversibles + SQL portable),
 *          H1 (pureté hexagonale Domain/Application), C1 (contrat OpenAPI présent),
 *          D1 (déployable : composer.lock versionné, un seul PHP dans public/, outils bin/ sans Composer).
 */
$root = dirname(__DIR__);
$failures = [];

/** G1 — aucun config.php réel commité ; le gabarit ne contient pas de secret en clair. */
if (is_file($root . '/src/config.php')) {
    // Toléré en local, mais ne doit jamais être versionné → vérifié par .gitignore.
    $gitignore = @file_get_contents($root . '/.gitignore') ?: '';
    if (!str_contains($gitignore, 'config.php')) {
        $failures[] = 'G1: src/config.php présent mais non ignoré par .gitignore.';
    }
}
$example = @file_get_contents($root . '/src/config.example.php') ?: '';
if (preg_match('/password\s*=>\s*[\'"][^\'"]{3,}[\'"]/', $example)) {
    $failures[] = 'G1: un mot de passe en clair figure dans config.example.php.';
}

// Le secret du noyau Symfony vient de la configuration de l'instance, jamais d'un littéral.
foreach (rglob($root . '/src', '*.php') as $file) {
    $code = strip_php_comments((string) file_get_contents($file));
    if (preg_match('/[\'"]secret[\'"]\s*=>\s*[\'"](?!%env\()[^\'"]+[\'"]/', $code) && basename($file) !== 'config.example.php') {
        $failures[] = 'G1: secret du noyau en dur dans ' . substr($file, strlen($root) + 1);
    }
}
if (preg_match('/[\'"]secret[\'"]\s*=>\s*[\'"][^\'"]+[\'"]/', strip_php_comments($example))) {
    $failures[] = 'G1: un secret en clair figure dans config.example.php.';
}
$gitignore = @file_get_contents($root . '/.gitignore') ?: '';
foreach (['/src/config.php', '/var/'] as $ignored) {
    if (!preg_match('#^' . preg_quote($ignored, '#') . '$#m', $gitignore)) {
        $failures[] = 'G1: ' . $ignored . ' (configuration ou état de l\'instance) doit être ignoré par .gitignore.';
    }
}

/** G2 — chaque migration *.up.sql a son *.down.sql ; pas de SQL non portable. */
$ups = glob($root . '/database/migrations/pending/*.up.sql') ?: [];
foreach ($ups as $up) {
    $down = preg_replace('/\.up\.sql$/', '.down.sql', $up);
    if (!is_file($down)) {
        $failures[] = 'G2: migration sans réversion : ' . basename($up);
    }
    $sql = strip_sql_comments((string) file_get_contents($up));
    if (preg_match('/\bNOW\(\)|\bAUTO_INCREMENT\b|datetime\(\s*[\'"]now/i', $sql)) {
        $failures[] = 'G2: SQL non portable (NOW()/AUTO_INCREMENT/datetime now) dans ' . basename($up);
    }
}

/** H1 — Domain et Application ne référencent aucun framework/PDO/SQL. */
$pureDirs = ['/src/Domain', '/src/Application'];
foreach ($pureDirs as $dir) {
    foreach (rglob($root . $dir, '*.php') as $file) {
        $code = strip_php_comments((string) file_get_contents($file));
        if (preg_match('/\bPDO\b|\bnew\s+PDO|Doctrine|Symfony\\\\|ApiPlatform\\\\|Laravel\\\\|\$this->db|->query\(|->prepare\(/', $code)) {
            $failures[] = 'H1: dépendance infrastructure dans une couche pure : ' . substr($file, strlen($root) + 1);
        }
    }
}

/** C1 — le contrat OpenAPI (source de vérité) est présent. La fraîcheur du client TYPÉ api.ts
 *  vs OpenAPI est vérifiée par le gate `contrat` (harness/run-contract.sh, image node). */
if (!is_file($root . '/openapi/todos.openapi.json')) {
    $failures[] = 'C1: openapi/todos.openapi.json absent (contrat matérialisé manquant).';
}

/** D1 — le kit est déployable tel quel sur un hébergement PHP infogéré. */
if (!is_file($root . '/composer.lock') || preg_match('#^/?composer\.lock$#m', $gitignore)) {
    $failures[] = 'D1: composer.lock doit être présent et versionné (dépendances identiques au gate et au déploiement).';
}
$servedPhp = array_map(static fn (string $f): string => substr($f, strlen($root) + 1), rglob($root . '/public', '*.php'));
if ($servedPhp !== ['public/index.php']) {
    $failures[] = 'D1: public/ ne doit contenir qu\'un fichier PHP, le contrôleur frontal index.php (trouvé : ' . implode(', ', $servedPhp) . ').';
}
if (!is_file($root . '/public/.htaccess')) {
    $failures[] = 'D1: public/.htaccess absent (réécriture de /api/* vers le contrôleur frontal).';
}
foreach (['bin/migrate.php', 'bin/account.php'] as $tool) {
    $code = strip_php_comments((string) @file_get_contents($root . '/' . $tool));
    if ($code === '' || str_contains($code, 'vendor/')) {
        $failures[] = 'D1: ' . $tool . ' doit exister et tourner sans Composer (commande courte sur le serveur).';
    }
}

if ($failures === []) {
    fwrite(STDOUT, "verify: 🟢 tous les invariants sont verts.\n");
    exit(0);
}
fwrite(STDERR, "verify: 🔴\n - " . implode("\n - ", $failures) . "\n");
exit(1);

/** Retire les commentaires SQL (`-- …`) pour ne scanner que le SQL exécutable. */
function strip_sql_comments(string $sql): string
{
    return preg_replace('/--[^\r\n]*/', '', $sql) ?? $sql;
}

/** Retire les commentaires PHP (docblocks, //, #) via le tokenizer. */
function strip_php_comments(string $code): string
{
    $out = '';
    foreach (token_get_all($code) as $tok) {
        if (is_array($tok)) {
            if ($tok[0] === T_COMMENT || $tok[0] === T_DOC_COMMENT) {
                continue;
            }
            $out .= $tok[1];
        } else {
            $out .= $tok;
        }
    }
    return $out;
}

/** @return list<string> */
function rglob(string $dir, string $pattern): array
{
    $out = [];
    if (!is_dir($dir)) {
        return $out;
    }
    $it = new RecursiveIteratorIterator(new RecursiveDirectoryIterator($dir, FilesystemIterator::SKIP_DOTS));
    foreach ($it as $f) {
        if ($f->isFile() && fnmatch($pattern, $f->getFilename())) {
            $out[] = $f->getPathname();
        }
    }
    return $out;
}

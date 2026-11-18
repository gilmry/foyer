<?php

declare(strict_types=1);

namespace TodoApp\Adapter\Migration;

use PDO;
use RuntimeException;

/**
 * Outil de migration — PDO seul, sans Composer (il tourne en commande courte sur le serveur).
 *
 * - applique dans l'ordre les `*.up.sql` du dossier qui ne sont pas encore passées ;
 * - les trace dans `schema_migrations` (version, somme de contrôle SHA-256, date) ;
 * - REFUSE d'avancer si la somme d'une migration déjà passée a changé, ou si son fichier a
 *   disparu : une migration appliquée ne se réécrit pas, on en écrit une nouvelle ;
 * - `down` annule la dernière passée par son `*.down.sql`.
 *
 * MySQL et MariaDB valident chaque instruction DDL à part : une migration qui échoue en cours de
 * route peut laisser le schéma à moitié changé. Elle n'est alors PAS tracée, et l'erreur est
 * rendue telle quelle : on corrige à la main avant de rejouer. Une instruction par `;` en fin
 * de ligne (pas de procédure stockée ici).
 */
final class Migrator
{
    private const TABLE = 'schema_migrations';

    public function __construct(private readonly PDO $db, private readonly string $dir)
    {
    }

    /** @return list<array{version:string,state:string,appliedAt:?string}> state : applied|pending|modified|missing */
    public function status(): array
    {
        $this->ensureTable();
        $applied = $this->applied();
        $files = $this->files();
        $out = [];
        foreach ($files as $version => $path) {
            if (!isset($applied[$version])) {
                $out[] = ['version' => $version, 'state' => 'pending', 'appliedAt' => null];
                continue;
            }
            $state = hash_equals($applied[$version]['checksum'], self::checksum($path)) ? 'applied' : 'modified';
            $out[] = ['version' => $version, 'state' => $state, 'appliedAt' => $applied[$version]['applied_at']];
        }
        foreach ($applied as $version => $row) {
            if (!isset($files[$version])) {
                $out[] = ['version' => $version, 'state' => 'missing', 'appliedAt' => $row['applied_at']];
            }
        }

        return $out;
    }

    /** @return list<string> versions appliquées par CET appel (vide si tout était déjà passé) */
    public function up(): array
    {
        $done = [];
        $this->locked(function () use (&$done): void {
            $pending = [];
            foreach ($this->status() as $m) {
                if ($m['state'] === 'modified') {
                    throw new RuntimeException(sprintf('Migration « %s » déjà appliquée mais MODIFIÉE depuis (somme de contrôle différente) : refus.', $m['version']));
                }
                if ($m['state'] === 'missing') {
                    throw new RuntimeException(sprintf('Migration « %s » appliquée mais ABSENTE du dossier : refus.', $m['version']));
                }
                if ($m['state'] === 'pending') {
                    $pending[] = $m['version'];
                }
            }
            $files = $this->files();
            foreach ($pending as $version) {
                $this->run($files[$version]);
                $this->db->prepare('INSERT INTO ' . self::TABLE . ' (version, checksum, applied_at) VALUES (?, ?, ?)')
                    ->execute([$version, self::checksum($files[$version]), gmdate('Y-m-d H:i:s')]);
                $done[] = $version;
            }
        });

        return $done;
    }

    /** @return ?string version annulée, ou null s'il n'y en avait aucune */
    public function down(): ?string
    {
        $undone = null;
        $this->locked(function () use (&$undone): void {
            $this->ensureTable();
            $applied = array_keys($this->applied());
            if ($applied === []) {
                return;
            }
            $version = end($applied);
            $down = $this->dir . '/' . $version . '.down.sql';
            if (!is_file($down)) {
                throw new RuntimeException(sprintf('Pas de fichier de réversion pour « %s ».', $version));
            }
            $this->run($down);
            $this->db->prepare('DELETE FROM ' . self::TABLE . ' WHERE version = ?')->execute([$version]);
            $undone = $version;
        });

        return $undone;
    }

    /** Découpe un fichier SQL en instructions (commentaires `--` retirés). */
    public static function statements(string $sql): array
    {
        $sql = preg_replace('/^\s*--.*$/m', '', $sql) ?? $sql;
        $parts = preg_split('/;\s*(?:\r?\n|$)/', $sql) ?: [];

        return array_values(array_filter(array_map('trim', $parts), static fn (string $s): bool => $s !== ''));
    }

    private function run(string $path): void
    {
        // Instruction par instruction : PDO::exec sur plusieurs instructions ne remonte que
        // l'erreur de la première.
        foreach (self::statements((string) file_get_contents($path)) as $statement) {
            $this->db->exec($statement);
        }
    }

    private function locked(callable $work): void
    {
        // Verrou nommé : deux déploiements simultanés ne jouent pas la même migration.
        $name = 'kit_migrations_' . (string) $this->db->query('SELECT DATABASE()')->fetchColumn();
        $s = $this->db->prepare('SELECT GET_LOCK(?, 10)');
        $s->execute([$name]);
        if ((int) $s->fetchColumn() !== 1) {
            throw new RuntimeException('Une autre migration est en cours.');
        }
        try {
            $work();
        } finally {
            $this->db->prepare('SELECT RELEASE_LOCK(?)')->execute([$name]);
        }
    }

    private function ensureTable(): void
    {
        $this->db->exec(
            'CREATE TABLE IF NOT EXISTS ' . self::TABLE . ' ('
            . 'version VARCHAR(191) NOT NULL, checksum CHAR(64) NOT NULL, applied_at DATETIME NOT NULL, '
            . 'PRIMARY KEY (version)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci'
        );
    }

    /** @return array<string,array{checksum:string,applied_at:string}> par version croissante */
    private function applied(): array
    {
        $rows = $this->db->query('SELECT version, checksum, applied_at FROM ' . self::TABLE . ' ORDER BY version')->fetchAll();
        $out = [];
        foreach ($rows as $row) {
            $out[(string) $row['version']] = ['checksum' => (string) $row['checksum'], 'applied_at' => (string) $row['applied_at']];
        }

        return $out;
    }

    /** @return array<string,string> version → chemin du .up.sql, par version croissante */
    private function files(): array
    {
        $out = [];
        foreach (glob($this->dir . '/*.up.sql') ?: [] as $path) {
            $out[basename($path, '.up.sql')] = $path;
        }
        ksort($out, SORT_STRING);

        return $out;
    }

    private static function checksum(string $path): string
    {
        return hash_file('sha256', $path);
    }
}

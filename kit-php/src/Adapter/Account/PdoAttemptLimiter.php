<?php

declare(strict_types=1);

namespace TodoApp\Adapter\Account;

use PDO;
use RuntimeException;

/**
 * Compteur d'essais à fenêtre glissante, EN BASE (table `attempt_windows`), sans service annexe.
 * Lire, décider et inscrire l'essai se font sous un verrou nommé de la base (GET_LOCK), propre à
 * la clé : deux requêtes simultanées ne peuvent pas passer toutes les deux sous le seuil.
 *
 * Pourquoi la base et pas des fichiers : le dossier du compte d'un hébergeur infogéré peut être un
 * partage réseau (NFS), où un verrou de fichier n'est pas garanti. Le verrou de la base, lui, se
 * comporte de la même façon sur le poste et chez l'hébergeur : la preuve locale vaut pour les deux.
 */
final class PdoAttemptLimiter
{
    public function __construct(private readonly PDO $db)
    {
    }

    /**
     * RÉSERVE un essai pour cette clé s'il en reste dans la fenêtre.
     *
     * @return array{accepted:bool,used:int,retryAfter:int} `used` = essais déjà inscrits avant celui-ci
     */
    public function reserve(string $key, int $limit, int $windowSeconds): array
    {
        $now = time();

        return $this->locked($key, static function (array $stamps) use ($now, $limit, $windowSeconds): array {
            $stamps = array_values(array_filter($stamps, static fn (int $t): bool => $t > $now - $windowSeconds));
            $used = count($stamps);
            $accepted = $used < $limit;
            if ($accepted) {
                $stamps[] = $now;
            }
            $retryAfter = $stamps === [] ? $now : min($stamps) + $windowSeconds;

            return [$stamps, ['accepted' => $accepted, 'used' => $used, 'retryAfter' => $retryAfter]];
        });
    }

    /** Rend le dernier essai réservé (connexion réussie : il ne compte pas contre l'adresse). */
    public function release(string $key): void
    {
        $this->locked($key, static function (array $stamps): array {
            array_pop($stamps);

            return [$stamps, null];
        });
    }

    /** Remet le compteur de la clé à zéro. */
    public function reset(string $key): void
    {
        $this->locked($key, static fn (array $stamps): array => [[], null]);
    }

    /** @param callable(list<int>):array{0:list<int>,1:mixed} $work */
    private function locked(string $key, callable $work): mixed
    {
        // La clé n'est jamais stockée en clair. Le nom du verrou est propre à la base ET à la clé
        // (GET_LOCK est global au serveur ; 64 caractères au plus sur MySQL).
        $hash = hash('sha256', $key);
        $lock = 'ka' . substr(hash('sha256', (string) $this->db->query('SELECT DATABASE()')->fetchColumn() . '|' . $key), 0, 62);
        $s = $this->db->prepare('SELECT GET_LOCK(?, 5)');
        $s->execute([$lock]);
        if ((int) $s->fetchColumn() !== 1) {
            throw new RuntimeException('Compteur d\'essais occupé.');
        }
        try {
            $s = $this->db->prepare('SELECT stamps FROM attempt_windows WHERE key_hash = ?');
            $s->execute([$hash]);
            $stored = $s->fetchColumn();
            $stamps = $stored === false ? [] : json_decode((string) $stored, true);
            [$stamps, $result] = $work(is_array($stamps) ? array_values(array_filter($stamps, 'is_int')) : []);
            if ($stored === false) {
                $this->db->prepare('INSERT INTO attempt_windows (key_hash, stamps, updated_at) VALUES (?, ?, ?)')
                    ->execute([$hash, json_encode($stamps), time()]);
            } else {
                $this->db->prepare('UPDATE attempt_windows SET stamps = ?, updated_at = ? WHERE key_hash = ?')
                    ->execute([json_encode($stamps), time(), $hash]);
            }

            return $result;
        } finally {
            $this->db->prepare('SELECT RELEASE_LOCK(?)')->execute([$lock]);
            if (random_int(1, 200) === 1) {
                // Ménage : les compteurs que plus personne n'a touchés depuis une heure.
                $this->db->prepare('DELETE FROM attempt_windows WHERE updated_at < ?')->execute([time() - 3600]);
            }
        }
    }
}

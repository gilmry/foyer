<?php

declare(strict_types=1);

namespace TodoApp\Domain\Todo;

/**
 * Règles de validation du domaine Todo — messages en français.
 * Appelées par les use-cases AVANT tout accès à la persistance.
 */
final class TodoRules
{
    public const TITLE_MAX = 255;

    /**
     * @param array<string,mixed> $input
     * @return list<string> liste d'erreurs (vide si valide)
     */
    public static function validate(array $input): array
    {
        $errors = [];
        $title = isset($input['title']) ? trim((string) $input['title']) : '';

        if ($title === '') {
            $errors[] = 'Le libellé est obligatoire.';
        } elseif (mb_strlen($title) > self::TITLE_MAX) {
            $errors[] = sprintf('Le libellé ne peut dépasser %d caractères.', self::TITLE_MAX);
        }

        return $errors;
    }

    /** Normalise un libellé (trim). */
    public static function normalizeTitle(string $title): string
    {
        return trim($title);
    }
}

<?php

declare(strict_types=1);

namespace TodoApp\Http\ApiPlatform\Resource;

use Symfony\Component\Validator\Constraints as Assert;
use TodoApp\Domain\Todo\TodoRules;

/**
 * Entrée de création d'une tâche. Un seul champ : aucun identifiant, aucun propriétaire, aucun
 * statut ne peut être fourni par le client. Les règles répètent celles du domaine (TodoRules),
 * qui restent appliquées par le cas d'usage : la validation HTTP ne fait que répondre plus tôt,
 * au format problème, champ par champ.
 */
final class TodoInput
{
    #[Assert\NotBlank(message: 'Le libellé est obligatoire.', normalizer: 'trim')]
    #[Assert\Length(max: TodoRules::TITLE_MAX, maxMessage: 'Le libellé ne peut dépasser {{ limit }} caractères.')]
    public ?string $title = null;
}

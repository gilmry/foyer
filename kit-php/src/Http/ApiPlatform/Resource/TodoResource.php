<?php

declare(strict_types=1);

namespace TodoApp\Http\ApiPlatform\Resource;

use ApiPlatform\Metadata\ApiProperty;
use ApiPlatform\Metadata\ApiResource;
use ApiPlatform\Metadata\Delete;
use ApiPlatform\Metadata\Get;
use ApiPlatform\Metadata\GetCollection;
use ApiPlatform\Metadata\Patch;
use ApiPlatform\Metadata\Post;
use ApiPlatform\Metadata\QueryParameter;
use TodoApp\Domain\Todo\Todo;
use TodoApp\Http\ApiPlatform\State\TodoStateProcessor;
use TodoApp\Http\ApiPlatform\State\TodoStateProvider;

/**
 * Ressource API Platform du périmètre Todo — un DTO de SORTIE, pas une entité Doctrine.
 * Les opérations délèguent aux cas d'usage via TodoStateProvider / TodoStateProcessor.
 *
 * - chaque opération DÉCLARE sa sécurité (second verrou, en plus d'access_control) ;
 * - l'entrée est un DTO séparé (TodoInput), validé, désérialisé strictement ;
 * - le propriétaire n'apparaît ni en entrée ni en sortie : il vient de l'identité.
 */
#[ApiResource(
    shortName: 'Todo',
    operations: [
        new GetCollection(
            provider: TodoStateProvider::class,
            security: "is_granted('ROLE_USER')",
            parameters: [
                'limit' => new QueryParameter(schema: ['type' => 'integer', 'minimum' => 1, 'maximum' => 100, 'default' => 50], description: 'Nombre maximal de tâches rendues (borné à 100).'),
                'offset' => new QueryParameter(schema: ['type' => 'integer', 'minimum' => 0, 'default' => 0], description: 'Nombre de tâches à passer.'),
            ],
        ),
        new Get(provider: TodoStateProvider::class, security: "is_granted('ROLE_USER')"),
        new Post(input: TodoInput::class, processor: TodoStateProcessor::class, security: "is_granted('ROLE_USER')"),
        new Patch(input: false, provider: TodoStateProvider::class, processor: TodoStateProcessor::class, security: "is_granted('ROLE_USER')"),
        new Delete(provider: TodoStateProvider::class, processor: TodoStateProcessor::class, security: "is_granted('ROLE_USER')"),
    ],
    formats: ['json' => ['application/json']],
    // Désérialisation stricte : tout champ inconnu (dont un champ propriétaire) est refusé (400).
    denormalizationContext: ['allow_extra_attributes' => false],
    security: "is_granted('ROLE_USER')",
    paginationEnabled: false,
)]
final class TodoResource
{
    #[ApiProperty(identifier: true)]
    public string $id = '';

    public string $title = '';

    public bool $done = false;

    public string $createdAt = '';

    public string $updatedAt = '';

    public static function fromDomain(Todo $t): self
    {
        return self::fromView($t->toView());
    }

    /** @param array{id:string,title:string,done:bool,createdAt:string,updatedAt:string} $view */
    public static function fromView(array $view): self
    {
        $r = new self();
        $r->id = $view['id'];
        $r->title = $view['title'];
        $r->done = $view['done'];
        $r->createdAt = $view['createdAt'];
        $r->updatedAt = $view['updatedAt'];

        return $r;
    }
}

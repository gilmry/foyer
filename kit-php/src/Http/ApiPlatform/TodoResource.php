<?php

declare(strict_types=1);

namespace TodoApp\Http\ApiPlatform;

use ApiPlatform\Metadata\ApiProperty;
use ApiPlatform\Metadata\ApiResource;
use ApiPlatform\Metadata\Delete;
use ApiPlatform\Metadata\Get;
use ApiPlatform\Metadata\GetCollection;
use ApiPlatform\Metadata\Patch;
use ApiPlatform\Metadata\Post;
use TodoApp\Domain\Todo\Todo;

/**
 * Ressource API Platform du périmètre Todo — un DTO, PAS une entité Doctrine.
 * Les opérations délèguent aux use-cases via TodoStateProvider / TodoStateProcessor : l'adaptateur
 * HTTP change (vanilla → API Platform), le domaine ne change pas.
 */
#[ApiResource(
    shortName: 'Todo',
    operations: [
        new GetCollection(provider: TodoStateProvider::class),
        new Get(provider: TodoStateProvider::class),
        new Post(processor: TodoStateProcessor::class),
        new Patch(processor: TodoStateProcessor::class, provider: TodoStateProvider::class),
        new Delete(processor: TodoStateProcessor::class, provider: TodoStateProvider::class),
    ],
    formats: ['json' => ['application/json']],
    paginationEnabled: false,
)]
final class TodoResource
{
    #[ApiProperty(identifier: true)]
    public ?string $id = null;

    public ?string $title = null;

    public bool $done = false;

    public ?string $createdAt = null;

    public ?string $updatedAt = null;

    public static function fromDomain(Todo $t): self
    {
        $r = new self();
        $r->id = $t->id();
        $r->title = $t->title();
        $r->done = $t->isDone();
        $r->createdAt = $t->createdAt()->format(DATE_ATOM);
        $r->updatedAt = $t->updatedAt()->format(DATE_ATOM);

        return $r;
    }
}

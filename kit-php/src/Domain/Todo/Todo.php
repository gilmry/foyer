<?php

declare(strict_types=1);

namespace TodoApp\Domain\Todo;

use DateTimeImmutable;

/**
 * Entité agrégat Todo — pure, immuable, sans dépendance externe.
 * Les invariants sont garantis par le constructeur : impossible de
 * construire une Todo dans un état illégal (libellé vide interdit).
 */
final class Todo
{
    public function __construct(
        private readonly string $id,
        private readonly string $title,
        private readonly bool $done,
        private readonly DateTimeImmutable $createdAt,
        private readonly DateTimeImmutable $updatedAt,
    ) {
        // Invariant métier codé dans le constructeur (cf. bmad/archetypes.md, stateful).
        if (trim($title) === '') {
            throw new TodoValidationException(['Le libellé est obligatoire.']);
        }
    }

    public function id(): string
    {
        return $this->id;
    }

    public function title(): string
    {
        return $this->title;
    }

    public function isDone(): bool
    {
        return $this->done;
    }

    public function createdAt(): DateTimeImmutable
    {
        return $this->createdAt;
    }

    public function updatedAt(): DateTimeImmutable
    {
        return $this->updatedAt;
    }

    /** Immuabilité : renvoie une copie avec le statut inversé. */
    public function toggled(DateTimeImmutable $now): self
    {
        return new self($this->id, $this->title, !$this->done, $this->createdAt, $now);
    }

    /** Immuabilité : renvoie une copie avec un nouveau libellé (post-MVP). */
    public function renamed(string $title, DateTimeImmutable $now): self
    {
        return new self($this->id, $title, $this->done, $this->createdAt, $now);
    }

    /**
     * Vue de sérialisation pour la couche HTTP — clés stables, ordre stable.
     * Source de vérité du schéma TodoView (openapi/todos.openapi.json).
     *
     * @return array{id:string,title:string,done:bool,createdAt:string,updatedAt:string}
     */
    public function toView(): array
    {
        return [
            'id' => $this->id,
            'title' => $this->title,
            'done' => $this->done,
            'createdAt' => $this->createdAt->format(DATE_ATOM),
            'updatedAt' => $this->updatedAt->format(DATE_ATOM),
        ];
    }
}

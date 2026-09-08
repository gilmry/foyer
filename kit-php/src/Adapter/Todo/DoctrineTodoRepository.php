<?php

declare(strict_types=1);

namespace TodoApp\Adapter\Todo;

use Doctrine\ORM\EntityManagerInterface;
use TodoApp\Adapter\Todo\Doctrine\TodoRecord;
use TodoApp\Domain\Todo\Todo;
use TodoApp\Domain\Todo\TodoRepository;

/**
 * Adaptateur de persistance — option ORM (Doctrine). Même port que CqrsTodoRepository.
 * Doctrine ne fuit jamais hors de l'adaptateur : on mappe TodoRecord ↔ entité de domaine Todo.
 * Schéma : les migrations up/down SQL communes, ou le schema-tool Doctrine (voir harness).
 */
final class DoctrineTodoRepository implements TodoRepository
{
    public function __construct(private readonly EntityManagerInterface $em)
    {
    }

    public function find(string $id): ?Todo
    {
        $record = $this->em->find(TodoRecord::class, $id);

        return $record ? self::toDomain($record) : null;
    }

    public function findAll(): array
    {
        $records = $this->em->getRepository(TodoRecord::class)
            ->findBy([], ['createdAt' => 'ASC', 'id' => 'ASC']);

        return array_map(self::toDomain(...), $records);
    }

    public function save(Todo $todo): void
    {
        $record = $this->em->find(TodoRecord::class, $todo->id()) ?? new TodoRecord();
        $record->id = $todo->id();
        $record->title = $todo->title();
        $record->done = $todo->isDone();
        $record->createdAt = $todo->createdAt();
        $record->updatedAt = $todo->updatedAt();
        $this->em->persist($record);
        $this->em->flush();
    }

    public function delete(string $id): void
    {
        $record = $this->em->find(TodoRecord::class, $id);
        if ($record !== null) {
            $this->em->remove($record);
            $this->em->flush();
        }
    }

    private static function toDomain(TodoRecord $r): Todo
    {
        return new Todo($r->id, $r->title, $r->done, $r->createdAt, $r->updatedAt);
    }
}

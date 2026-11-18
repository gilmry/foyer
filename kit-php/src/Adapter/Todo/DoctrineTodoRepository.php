<?php

declare(strict_types=1);

namespace TodoApp\Adapter\Todo;

use Doctrine\ORM\EntityManagerInterface;
use TodoApp\Adapter\Todo\Doctrine\TodoRecord;
use TodoApp\Domain\Todo\OwnershipViolationException;
use TodoApp\Domain\Todo\Todo;
use TodoApp\Domain\Todo\TodoRepository;

/**
 * Adaptateur de persistance — option ORM (Doctrine). Même port que CqrsTodoRepository.
 * Doctrine ne fuit jamais hors de l'adaptateur : on mappe TodoRecord ↔ entité de domaine Todo.
 * Schéma : les migrations up/down SQL communes (bin/migrate.php).
 * Chaque lecture filtre sur `ownerId` ; chaque écriture vérifie le propriétaire de la ligne.
 */
final class DoctrineTodoRepository implements TodoRepository
{
    public function __construct(private readonly EntityManagerInterface $em)
    {
    }

    public function find(string $ownerId, string $id): ?Todo
    {
        $record = $this->em->getRepository(TodoRecord::class)->findOneBy(['id' => $id, 'ownerId' => $ownerId]);

        return $record ? self::toDomain($record) : null;
    }

    public function findAll(string $ownerId, int $limit, int $offset = 0): array
    {
        $records = $this->em->getRepository(TodoRecord::class)
            ->findBy(['ownerId' => $ownerId], ['createdAt' => 'ASC', 'id' => 'ASC'], max(0, $limit), max(0, $offset));

        return array_map(self::toDomain(...), $records);
    }

    public function save(string $ownerId, Todo $todo): void
    {
        if ($todo->ownerId() !== $ownerId) {
            throw new OwnershipViolationException();
        }
        $record = $this->em->find(TodoRecord::class, $todo->id());
        if ($record !== null && $record->ownerId !== $ownerId) {
            throw new OwnershipViolationException();
        }
        $record ??= new TodoRecord();
        $record->id = $todo->id();
        $record->ownerId = $ownerId;
        $record->title = $todo->title();
        $record->done = $todo->isDone();
        $record->createdAt = $todo->createdAt();
        $record->updatedAt = $todo->updatedAt();
        $this->em->persist($record);
        $this->em->flush();
    }

    public function delete(string $ownerId, string $id): void
    {
        $record = $this->em->getRepository(TodoRecord::class)->findOneBy(['id' => $id, 'ownerId' => $ownerId]);
        if ($record !== null) {
            $this->em->remove($record);
            $this->em->flush();
        }
    }

    private static function toDomain(TodoRecord $r): Todo
    {
        return new Todo($r->id, $r->ownerId, $r->title, $r->done, $r->createdAt, $r->updatedAt);
    }
}

<?php

declare(strict_types=1);

namespace TodoApp\Adapter\Todo\Doctrine;

use DateTimeImmutable;
use Doctrine\ORM\Mapping as ORM;

/**
 * Entité de PERSISTANCE Doctrine — vit dans l'adaptateur, PAS dans le domaine.
 * Le domaine (Todo) reste pur ; on mappe TodoRecord ↔ Todo dans DoctrineTodoRepository.
 */
#[ORM\Entity]
#[ORM\Table(name: 'todos')]
class TodoRecord
{
    #[ORM\Id]
    #[ORM\Column(type: 'string', length: 64)]
    public string $id = '';

    #[ORM\Column(type: 'string', length: 255)]
    public string $title = '';

    #[ORM\Column(type: 'boolean')]
    public bool $done = false;

    #[ORM\Column(name: 'created_at', type: 'datetime_immutable')]
    public DateTimeImmutable $createdAt;

    #[ORM\Column(name: 'updated_at', type: 'datetime_immutable')]
    public DateTimeImmutable $updatedAt;
}

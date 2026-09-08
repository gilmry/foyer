<?php

declare(strict_types=1);

namespace TodoApp;

use PDO;
use TodoApp\Adapter\Todo\PdoTodoRepository;
use TodoApp\Adapter\Todo\RealClock;
use TodoApp\Adapter\Todo\UuidGenerator;
use TodoApp\Application\Todo\CreateTodo;
use TodoApp\Application\Todo\DeleteTodo;
use TodoApp\Application\Todo\ListTodos;
use TodoApp\Application\Todo\ToggleTodo;
use TodoApp\Domain\Todo\TodoNotFoundException;
use TodoApp\Domain\Todo\TodoRepository;
use TodoApp\Domain\Todo\TodoValidationException;
use TodoApp\Http\Request;
use TodoApp\Http\Response;

/**
 * Routeur applicatif — câble les routes REST du périmètre Todo vers les use-cases.
 * Seule couche qui traduit les exceptions du domaine en codes HTTP.
 */
final class Application
{
    private ?PDO $pdo = null;

    /** @param array<string,mixed> $config */
    public function __construct(private readonly array $config)
    {
    }

    public function handle(): void
    {
        $this->route(Request::fromGlobals());
    }

    private function route(Request $r): void
    {
        $m = $r->method();
        $p = rtrim($r->path(), '/') ?: '/';

        if ($p === '/api/todos' && $m === 'GET') {
            $this->listTodos();
            return;
        }
        if ($p === '/api/todos' && $m === 'POST') {
            $this->createTodo($r);
            return;
        }
        if (preg_match('#^/api/todos/([^/]+)$#', $p, $x) && $m === 'PATCH') {
            $this->toggleTodo(rawurldecode($x[1]));
            return;
        }
        if (preg_match('#^/api/todos/([^/]+)$#', $p, $x) && $m === 'DELETE') {
            $this->deleteTodo(rawurldecode($x[1]));
            return;
        }

        Response::json(['error' => 'Route introuvable.'], 404);
    }

    private function listTodos(): void
    {
        $uc = new ListTodos($this->repo());
        Response::json(['items' => $uc->execute()]);
    }

    private function createTodo(Request $r): void
    {
        $uc = new CreateTodo($this->repo(), new RealClock(), new UuidGenerator());
        try {
            $todo = $uc->execute($r->json());
        } catch (TodoValidationException $e) {
            Response::json(['errors' => $e->errors()], 400);
            return;
        }
        Response::json($todo->toView(), 201);
    }

    private function toggleTodo(string $id): void
    {
        $uc = new ToggleTodo($this->repo(), new RealClock());
        try {
            $todo = $uc->execute($id);
        } catch (TodoNotFoundException $e) {
            Response::json(['error' => $e->getMessage()], 404);
            return;
        }
        Response::json($todo->toView());
    }

    private function deleteTodo(string $id): void
    {
        $uc = new DeleteTodo($this->repo());
        try {
            $res = $uc->execute($id);
        } catch (TodoNotFoundException $e) {
            Response::json(['error' => $e->getMessage()], 404);
            return;
        }
        Response::json($res);
    }

    private function repo(): TodoRepository
    {
        return new PdoTodoRepository($this->db());
    }

    private function db(): PDO
    {
        return $this->pdo ??= Database::connect($this->config);
    }
}

<?php

declare(strict_types=1);

namespace TodoApp;

use TodoApp\Adapter\Account\FixedCurrentUser;
use TodoApp\Adapter\Services;
use TodoApp\Application\Account\ResolveAccessToken;
use TodoApp\Application\Account\RevokeAccessToken;
use TodoApp\Application\Todo\CreateTodo;
use TodoApp\Application\Todo\DeleteTodo;
use TodoApp\Application\Todo\GetTodo;
use TodoApp\Application\Todo\ListTodos;
use TodoApp\Application\Todo\ToggleTodo;
use TodoApp\Domain\Account\AuthenticationRequiredException;
use TodoApp\Domain\Account\CurrentUser;
use TodoApp\Domain\Todo\TodoNotFoundException;
use TodoApp\Domain\Todo\TodoValidationException;
use TodoApp\Http\MalformedRequestException;
use TodoApp\Http\Problem;
use TodoApp\Http\Request;
use TodoApp\Http\Response;

/**
 * Adaptateur HTTP vanilla — routeur maison, sans Composer. Câble les routes REST du périmètre
 * Todo vers les MÊMES cas d'usage que l'adaptateur API Platform, sous le même contrat OpenAPI.
 *
 * Authentification : JETON PORTEUR seulement, vérifié contre la table `access_tokens` (ADR-001).
 * Cet adaptateur n'ouvre pas de session, ne connecte pas par mot de passe, n'inscrit pas et
 * n'émet pas de jeton : ces routes n'y existent pas.
 */
final class Application
{
    public function __construct(private readonly Services $services)
    {
    }

    public function handle(): void
    {
        $request = Request::fromGlobals();
        try {
            $this->route($request);
        } catch (AuthenticationRequiredException) {
            Response::problem(401, 'Jeton porteur requis.');
        } catch (MalformedRequestException $e) {
            Response::problem(400, $e->getMessage());
        } catch (TodoValidationException $e) {
            Response::problem(422, null, array_map(
                static fn (string $message): array => ['propertyPath' => 'title', 'message' => $message],
                $e->errors(),
            ));
        } catch (TodoNotFoundException) {
            Response::problem(404, 'Ressource introuvable.');
        } catch (\Throwable $e) {
            // Aucune trace dans la réponse ; la classe de l'erreur va au journal du serveur.
            error_log('kit-php (vanilla) : ' . $e::class);
            Response::problem(Problem::isDatabaseFailure($e) ? 503 : 500);
        }
    }

    private function route(Request $r): void
    {
        $m = $r->method();
        $p = rtrim($r->path(), '/') ?: '/';
        $config = $this->services->config();

        if ($p === '/api/health' && $m === 'GET') {
            $this->services->pdo()->query('SELECT 1');
            Response::json([
                'status' => 'ok',
                'version' => $config['version'],
                'http' => 'vanilla',
                'persistence' => $config['persistence'],
                'auth' => ['bearer'],
                'registration' => 'closed',
            ]);

            return;
        }

        // Tout le reste de /api exige une identité : elle est établie AVANT le routage, pour que
        // la réponse sans jeton soit 401 quelle que soit la route (existante ou non).
        $user = $this->authenticate($r);
        $accountId = $user->id();

        if ($p === '/api/me' && $m === 'GET') {
            $account = $this->services->accounts()->findById($accountId);
            if ($account === null) {
                throw new AuthenticationRequiredException();
            }
            Response::json($account->toView());

            return;
        }
        if ($p === '/api/tokens/current' && $m === 'DELETE') {
            (new RevokeAccessToken($this->services->tokens()))->execute((string) $r->bearerToken());
            Response::noContent();

            return;
        }
        if ($p === '/api/todos' && $m === 'GET') {
            $uc = new ListTodos($this->services->todos(), $user);
            Response::json($uc->execute($r->queryInt('limit', ListTodos::DEFAULT_LIMIT), $r->queryInt('offset', 0)));

            return;
        }
        if ($p === '/api/todos' && $m === 'POST') {
            $uc = new CreateTodo($this->services->todos(), $this->services->clock(), $this->services->ids(), $user);
            $input = $r->json(['title']);
            if (array_key_exists('title', $input) && !is_string($input['title'])) {
                throw new MalformedRequestException('Le libellé doit être une chaîne.');
            }
            Response::json($uc->execute($input)->toView(), 201);

            return;
        }
        if (preg_match('#^/api/todos/([^/]+)$#', $p, $x)) {
            $id = rawurldecode($x[1]);
            if ($m === 'GET') {
                Response::json((new GetTodo($this->services->todos(), $user))->execute($id)->toView());

                return;
            }
            if ($m === 'PATCH') {
                $uc = new ToggleTodo($this->services->todos(), $this->services->clock(), $user);
                Response::json($uc->execute($id)->toView());

                return;
            }
            if ($m === 'DELETE') {
                (new DeleteTodo($this->services->todos(), $user))->execute($id);
                Response::noContent();

                return;
            }
        }

        Response::problem(404, 'Ressource introuvable.');
    }

    private function authenticate(Request $r): CurrentUser
    {
        $token = $r->bearerToken();
        if ($token === null) {
            return new FixedCurrentUser(null);
        }
        $resolve = new ResolveAccessToken($this->services->tokens(), $this->services->clock());

        return new FixedCurrentUser($resolve->execute($token));
    }
}

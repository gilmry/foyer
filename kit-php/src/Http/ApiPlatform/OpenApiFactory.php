<?php

declare(strict_types=1);

namespace TodoApp\Http\ApiPlatform;

use ApiPlatform\OpenApi\Factory\OpenApiFactoryInterface;
use ApiPlatform\OpenApi\Model\Operation;
use ApiPlatform\OpenApi\Model\PathItem;
use ApiPlatform\OpenApi\Model\RequestBody;
use ApiPlatform\OpenApi\Model\SecurityScheme;
use ApiPlatform\OpenApi\OpenApi;

/**
 * Complète la documentation OpenAPI produite par API Platform : les deux schémas de sécurité
 * (cookie de session, jeton porteur), leur exigence sur chaque opération, et les routes de compte
 * qui ne sont pas des ressources. Le contrat de référence reste openapi/todos.openapi.json ; le
 * gate e2e vérifie que cette documentation couvre chacune de ses opérations.
 */
final class OpenApiFactory implements OpenApiFactoryInterface
{
    private const SECURED = [['sessionCookie' => []], ['bearerToken' => []]];

    public function __construct(private readonly OpenApiFactoryInterface $inner)
    {
    }

    public function __invoke(array $context = []): OpenApi
    {
        $openApi = ($this->inner)($context);

        $schemes = $openApi->getComponents()->getSecuritySchemes() ?? new \ArrayObject();
        $schemes['sessionCookie'] = new SecurityScheme(type: 'apiKey', description: 'Session ouverte par POST /api/login.', name: Kernel::SESSION_COOKIE, in: 'cookie');
        $schemes['bearerToken'] = new SecurityScheme(type: 'http', description: 'Jeton opaque émis par POST /api/tokens.', scheme: 'bearer');
        $openApi = $openApi->withComponents($openApi->getComponents()->withSecuritySchemes($schemes));

        $paths = $openApi->getPaths();
        foreach ($paths->getPaths() as $path => $item) {
            foreach (['Get', 'Post', 'Patch', 'Put', 'Delete'] as $method) {
                $operation = $item->{'get' . $method}();
                if ($operation instanceof Operation) {
                    $item = $item->{'with' . $method}($operation->withSecurity(self::SECURED));
                }
            }
            $paths->addPath($path, $item);
        }

        $credentials = new RequestBody(content: new \ArrayObject(['application/json' => ['schema' => [
            'type' => 'object', 'required' => ['email', 'password'], 'additionalProperties' => false,
            'properties' => ['email' => ['type' => 'string', 'format' => 'email'], 'password' => ['type' => 'string', 'format' => 'password']],
        ]]]), required: true);
        $public = static fn (string $id, string $summary, array $responses, ?RequestBody $body = null): Operation
            => new Operation(operationId: $id, tags: ['Compte'], responses: $responses, summary: $summary, requestBody: $body, security: []);
        $secured = static fn (string $id, string $summary, array $responses, array $security = self::SECURED): Operation
            => new Operation(operationId: $id, tags: ['Compte'], responses: $responses, summary: $summary, security: $security);

        $paths->addPath('/api/login', new PathItem(post: $public('login', 'Ouvre une session (cookie)', ['200' => ['description' => 'Session ouverte'], '401' => ['description' => 'Identifiants refusés'], '429' => ['description' => 'Trop de tentatives']], $credentials)));
        $paths->addPath('/api/logout', new PathItem(post: $secured('logout', 'Ferme la session', ['204' => ['description' => 'Session fermée']], [['sessionCookie' => []]])));
        $paths->addPath('/api/register', new PathItem(post: $public('register', 'Crée un compte (si l\'inscription est ouverte)', ['202' => ['description' => 'Demande acceptée (même réponse que le courriel ait déjà un compte ou non)'], '403' => ['description' => 'Inscription fermée'], '422' => ['description' => 'Validation refusée'], '429' => ['description' => 'Trop de demandes']], $credentials)));
        $paths->addPath('/api/tokens', new PathItem(post: $public('issueToken', 'Émet un jeton porteur', ['201' => ['description' => 'Jeton émis'], '401' => ['description' => 'Identifiants refusés'], '429' => ['description' => 'Trop de tentatives']], $credentials)));
        $paths->addPath('/api/tokens/current', new PathItem(delete: $secured('revokeToken', 'Révoque le jeton porteur courant', ['204' => ['description' => 'Jeton révoqué']], [['bearerToken' => []]])));
        $paths->addPath('/api/me', new PathItem(get: $secured('me', 'Compte courant', ['200' => ['description' => 'Compte courant'], '401' => ['description' => 'Authentification requise']])));
        $paths->addPath('/api/health', new PathItem(get: $public('health', 'Sonde de santé', ['200' => ['description' => 'Service et base joignables'], '503' => ['description' => 'Service indisponible']])));

        return $openApi;
    }
}

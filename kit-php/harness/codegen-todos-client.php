<?php

declare(strict_types=1);

/**
 * Codegen : génère public/generated/todos.client.js depuis openapi/todos.openapi.json.
 * Le client est la SEULE porte d'accès du front à l'API (anti-drift : l'îlot n'écrit jamais d'URL en dur).
 * Rejouable ; le gate `contrat` vérifie que le fichier généré est à jour vs la spec.
 */
$root = dirname(__DIR__);
$specPath = $root . '/openapi/todos.openapi.json';
$outPath = getenv('TODOS_CLIENT_OUT') ?: $root . '/public/generated/todos.client.js';

$spec = json_decode((string) file_get_contents($specPath), true);
if (!is_array($spec) || !isset($spec['paths'])) {
    fwrite(STDERR, "Spec OpenAPI invalide.\n");
    exit(1);
}

/** Construit une méthode JS par operationId. */
$methods = [];
foreach ($spec['paths'] as $path => $ops) {
    foreach (['get', 'post', 'patch', 'delete'] as $http) {
        if (!isset($ops[$http]['operationId'])) {
            continue;
        }
        $opId = $ops[$http]['operationId'];
        $hasId = str_contains($path, '{id}');
        $hasBody = isset($ops[$http]['requestBody']);
        $jsPath = str_replace('{id}', '${encodeURIComponent(id)}', ltrim($path, '/'));

        $args = [];
        if ($hasId) {
            $args[] = 'id';
        }
        if ($hasBody) {
            $args[] = 'input';
        }
        $argList = implode(', ', $args);

        $opts = "{ method: '" . strtoupper($http) . "'";
        if ($hasBody) {
            $opts .= ', body: JSON.stringify(input)';
        }
        $opts .= ' }';

        $methods[] = sprintf(
            "    %s: function (%s) {\n      return transport(`%s`, %s);\n    }",
            $opId,
            $argList,
            $jsPath,
            $opts,
        );
    }
}

$code = "// GÉNÉRÉ depuis openapi/todos.openapi.json — NE PAS ÉDITER À LA MAIN (gate contrat).\n"
    . "function createTodosClient(transport) {\n"
    . "  return {\n"
    . implode(",\n", $methods) . ",\n"
    . "  };\n"
    . "}\n"
    . "if (typeof window !== 'undefined') { window.createTodosClient = createTodosClient; }\n"
    . "if (typeof module !== 'undefined') { module.exports = { createTodosClient }; }\n";

@mkdir(dirname($outPath), 0o755, true);
file_put_contents($outPath, $code);
fwrite(STDOUT, "Client généré : " . $outPath . "\n");

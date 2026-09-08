// gen-api.mjs — génère un client TypeScript TYPÉ (src/generated/api.ts) depuis le contrat OpenAPI.
// Source de vérité : ../openapi/todos.openapi.json. Le front ne connaît d'URL/endpoint que via ce
// client généré (anti-drift). Lancé par `npm run prebuild`. NE PAS éditer api.ts à la main.
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = dirname(fileURLToPath(import.meta.url));
const SPEC = resolve(HERE, '../../openapi/todos.openapi.json');
const OUT = process.env.API_TS_OUT || resolve(HERE, '../src/generated/api.ts');

const spec = JSON.parse(readFileSync(SPEC, 'utf8'));
const schemas = spec.components?.schemas ?? {};

const refName = (ref) => ref.split('/').pop();

function tsType(schema) {
  if (!schema) return 'unknown';
  if (schema.$ref) return refName(schema.$ref);
  if (schema.anyOf) {
    const parts = schema.anyOf.map(tsType).filter((t) => t !== 'null');
    const nullable = schema.anyOf.some((s) => s.type === 'null');
    return parts.join(' | ') + (nullable ? ' | null' : '');
  }
  switch (schema.type) {
    case 'string': return 'string';
    case 'integer':
    case 'number': return 'number';
    case 'boolean': return 'boolean';
    case 'array': {
      const it = tsType(schema.items);
      return /[|&]/.test(it) ? `(${it})[]` : `${it}[]`;
    }
    case 'object':
    default:
      if (schema.properties) {
        const req = new Set(schema.required ?? []);
        const fields = Object.entries(schema.properties)
          .map(([k, v]) => `  ${k}${req.has(k) ? '' : '?'}: ${tsType(v)};`)
          .join('\n');
        return `{\n${fields}\n}`;
      }
      return 'unknown';
  }
}

// 1. Interfaces des schémas nommés (objets uniquement).
const interfaces = Object.entries(schemas)
  .filter(([, s]) => s.type === 'object' && s.properties)
  .map(([name, s]) => `export interface ${name} ${tsType(s)}`)
  .join('\n\n');

// 2. Méthodes typées par operationId.
const successOf = (op) => op.responses?.['200'] ?? op.responses?.['201'];
const bodySchema = (op) => op.requestBody?.content?.['application/json']?.schema;
const respSchema = (op) => successOf(op)?.content?.['application/json']?.schema;

const methods = [];
for (const [path, ops] of Object.entries(spec.paths ?? {})) {
  for (const http of ['get', 'post', 'patch', 'delete']) {
    const op = ops[http];
    if (!op?.operationId) continue;
    const hasId = path.includes('{id}');
    const body = bodySchema(op);
    const ret = respSchema(op) ? tsType(respSchema(op)) : 'unknown';
    const jsPath = path.replace(/^\//, '').replace('{id}', '${encodeURIComponent(id)}');
    const args = [hasId ? 'id: string' : null, body ? `input: ${tsType(body)}` : null].filter(Boolean).join(', ');
    let opts = `{ method: '${http.toUpperCase()}'`;
    if (body) opts += ", body: JSON.stringify(input)";
    opts += ' }';
    methods.push(
      `    ${op.operationId}: (${args}): Promise<${ret}> =>\n` +
      `      transport(\`${jsPath}\`, ${opts}) as Promise<${ret}>,`
    );
  }
}

const out = `// GÉNÉRÉ depuis openapi/todos.openapi.json par frontend-todos/scripts/gen-api.mjs.
// NE PAS ÉDITER À LA MAIN — regénéré par \`npm run prebuild\` ; le gate contrat vérifie sa fraîcheur.

export type Transport = (
  url: string,
  options?: { method?: string; body?: string; headers?: Record<string, string> },
) => Promise<unknown>;

${interfaces}

export function createTodosClient(transport: Transport) {
  return {
${methods.join('\n')}
  };
}
`;

mkdirSync(dirname(OUT), { recursive: true });
writeFileSync(OUT, out);
console.log(`api.ts généré : ${OUT}`);

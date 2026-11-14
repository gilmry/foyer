#!/usr/bin/env bash
# Gate `chiffrement` (foyer#28) — les quatre scénarios du port Chiffreur contre le serveur actix
# réel, PostgreSQL et OpenBao en mode dev : @happy dans les quatre variantes, @negative (OpenBao
# arrêté → 503 sans aucun champ), @edge (expiration du cache), @security (rien en clair en base).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/harness/ensure-images.sh"; ensure_rust_image; ensure_postgres; ensure_openbao
PORT=8081
BASE="http://127.0.0.1:$PORT"
TTL=2

docker run --rm -v "$ROOT":/app -w /app "${CARGO_VOLS[@]}" todo-kit-rust:local cargo build --quiet --bin server
reset_schema_mesure

cid=""
arreter() { [ -n "$cid" ] && docker stop "$cid" >/dev/null 2>&1 || true; cid=""; }
trap 'arreter; docker stop todo-openbao >/dev/null 2>&1 || true' EXIT

demarrer() { # $1 = variante
  arreter
  cid=$(docker run -d --rm --network host -v "$ROOT":/app -w /app "${CARGO_VOLS[@]}" \
    -e DB_HOST=127.0.0.1 -e DB_PORT="$KIT_PG_PORT" -e DB_NAME=todo -e DB_USER=todo -e DB_PASSWORD=todo \
    -e HTTP_HOST=127.0.0.1 -e HTTP_PORT=$PORT \
    -e CHIFFREMENT="$1" -e CHIFFREMENT_CACHE_TTL_S=$TTL \
    -e OPENBAO_ADDR="http://127.0.0.1:$OPENBAO_PORT" -e OPENBAO_JETON="$OPENBAO_JETON_DEV" \
    todo-kit-rust:local ./target/debug/server)
  local i
  for i in $(seq 1 40); do curl -sf "$BASE/api/mesure/compteurs" >/dev/null 2>&1 && return 0; sleep 0.5; done
  echo "  ✗ serveur $1 injoignable"; docker logs "$cid" 2>&1 | tail -5; return 1
}

fail=0
assert() { if [ "$2" = "$3" ]; then echo "  ✓ $1"; else echo "  ✗ $1 : attendu « $2 », obtenu « $3 »"; fail=1; fi; }
champ() { printf '%s' "$1" | sed -n "s/.*\"$2\":\"\([^\"]*\)\".*/\1/p"; }
compteur() { curl -s "$BASE/api/mesure/compteurs" | sed -n "s/.*\"$1\":\([0-9]*\).*/\1/p"; }
sql() { docker exec todo-postgres psql -U todo -d todo -tAc "$1"; }

NOM="Ada Lovelace"; COURRIEL="ada@exemple.invalid"; TEL="+32 2 000 00 00"
ecrire() {
  curl -s -X POST "$BASE/api/personnes" -H 'Content-Type: application/json' \
    -d "{\"nom\":\"$NOM\",\"courriel\":\"$COURRIEL\",\"telephone\":\"$TEL\"}"
}

for variante in clair local openbao openbao-cache; do
  echo "[$variante]"
  demarrer "$variante"
  id=$(champ "$(ecrire)" id)
  relue=$(curl -s "$BASE/api/personnes/$id")
  # @happy
  assert "@happy relit le nom" "$NOM" "$(champ "$relue" nom)"
  assert "@happy relit le courriel" "$COURRIEL" "$(champ "$relue" courriel)"
  assert "@happy relit le téléphone" "$TEL" "$(champ "$relue" telephone)"
  # @security : la ligne lue directement en SQL
  en_clair=$(sql "SELECT (position(convert_to('$NOM','UTF8') in nom) > 0) OR (position(convert_to('$COURRIEL','UTF8') in courriel) > 0) OR (position(convert_to('$TEL','UTF8') in telephone) > 0) FROM personnes WHERE id = '$id'")
  case "$variante" in
    clair)
      assert "@security témoin : la variante clair stocke bien du clair" t "$en_clair" ;;
    local)
      assert "@security aucun champ en clair" f "$en_clair"
      assert "@security clé enveloppée (nonce ‖ clé ‖ étiquette = 60 octets)" 60 "$(sql "SELECT length(cle_enveloppee) FROM personnes WHERE id = '$id'")" ;;
    openbao*)
      assert "@security aucun champ en clair" f "$en_clair"
      assert "@security clé enveloppée par transit" t "$(sql "SELECT convert_from(cle_enveloppee,'UTF8') LIKE 'vault:v1:%' FROM personnes WHERE id = '$id'")" ;;
  esac
done

# @edge — openbao-cache : l'écriture met la clé en cache, la première lecture n'appelle pas
# OpenBao, la seconde (après le TTL) si. Le serveur openbao-cache tourne encore.
echo "[@edge cache de ${TTL} s]"
id=$(champ "$(ecrire)" id)
d0=$(compteur openbao_desenveloppements)
curl -s -o /dev/null "$BASE/api/personnes/$id"
d1=$(compteur openbao_desenveloppements)
sleep $((TTL + 1))
curl -s -o /dev/null "$BASE/api/personnes/$id"
d2=$(compteur openbao_desenveloppements)
assert "@edge lecture avant expiration : aucun désenveloppement" 0 "$((d1 - d0))"
assert "@edge lecture après expiration : un désenveloppement" 1 "$((d2 - d1))"

# Témoin : sans cache, chaque lecture désenveloppe.
demarrer openbao
id=$(champ "$(ecrire)" id)
d0=$(compteur openbao_desenveloppements)
curl -s -o /dev/null "$BASE/api/personnes/$id"; curl -s -o /dev/null "$BASE/api/personnes/$id"
assert "@edge témoin sans cache : deux lectures, deux désenveloppements" 2 "$(( $(compteur openbao_desenveloppements) - d0 ))"

# @negative — OpenBao arrêté : 503, et aucun champ dans la réponse.
echo "[@negative OpenBao arrêté]"
docker stop todo-openbao >/dev/null
reponse=$(curl -s -w '\n%{http_code}' "$BASE/api/personnes/$id")
assert "@negative relecture → 503" 503 "$(printf '%s' "$reponse" | tail -1)"
assert "@negative aucun champ renvoyé" 0 "$(printf '%s' "$reponse" | grep -cE 'Ada|exemple\.invalid|"nom"|"courriel"' || true)"

echo ""
if [ "$fail" = 0 ]; then echo "chiffrement (foyer#28): 🟢"; else echo "chiffrement: 🔴"; fi
exit "$fail"

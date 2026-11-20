#!/usr/bin/env bash
# Prépare la livraison SUR LE POSTE : le serveur n'installe ni ne compile rien.
#
# Les dépendances d'EXÉCUTION sont installées dans un dossier (`pip install --target`) à partir
# du verrou requirements.lock (versions et empreintes exigées, aucune résolution), dans l'image de
# la cible : Debian 12 (glibc 2.36), Python 3.12. Les modules compilés (psycopg, pydantic-core,
# argon2) sont donc ceux que le Python 3.12 de l'hébergeur sait charger.
#
# Produit deploiement/alwaysdata/dist/livraison.tgz : app/, database/, public/, deps/, lancer.sh,
# wsgi.py, VERSION.
# Ni tests, ni harnais, ni front source, ni .git, ni fichier d'environnement.
set -euo pipefail
ICI="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RACINE="$(cd "$ICI/../.." && pwd)"
IMAGE="${KIT_IMAGE_CIBLE:-python:3.12-slim-bookworm}"
DIST="$ICI/dist"
rm -rf "$DIST"; mkdir -p "$DIST/livraison"

docker run --rm -v "$RACINE/requirements.lock":/requirements.lock:ro -v "$DIST/livraison":/sortie \
  -e PIP_DISABLE_PIP_VERSION_CHECK=1 -e PIP_ROOT_USER_ACTION=ignore "$IMAGE" sh -ec '
    pip install -q --no-cache-dir --no-deps --require-hashes --no-compile \
      --target /sortie/deps -r /requirements.lock
    rm -rf /sortie/deps/bin
    chown -R "$(stat -c %u:%g /sortie)" /sortie/deps
  '
cp -R "$RACINE/app" "$RACINE/database" "$RACINE/public" "$DIST/livraison/"
# Les deux points d'entrée voyagent DANS la version : ils basculent avec elle.
cp "$ICI/lancer.sh" "$RACINE/wsgi.py" "$DIST/livraison/"
chmod 755 "$DIST/livraison/lancer.sh"
find "$DIST/livraison" -name __pycache__ -type d -prune -exec rm -rf {} +
rm -f "$DIST/livraison/app/config_local.py"
# Identité de la version : empreinte de son contenu, lisible sur le serveur (courant/VERSION).
(cd "$DIST/livraison" && find . -type f ! -name VERSION -print0 | sort -z | xargs -0 sha256sum | sha256sum | cut -c1-12) > "$DIST/livraison/VERSION"
tar -C "$DIST/livraison" -czf "$DIST/livraison.tgz" .
rm -rf "$DIST/livraison"
echo "  livraison prête : $(du -h "$DIST/livraison.tgz" | cut -f1), version $(tar -xzOf "$DIST/livraison.tgz" ./VERSION)"

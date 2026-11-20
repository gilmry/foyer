"""Gabarit de configuration. Tout vient de l'environnement (voir app/config.py) ; aucun secret réel
ici (gate plancher G1). Sur un hébergement, ces variables vivent dans un fichier `.env` à droits
600, créé sur le serveur par deploiement/alwaysdata/deployer.sh."""

# Exemple de variables (à exporter dans l'environnement, jamais à committer avec de vraies valeurs) :
#   DB_HOST=localhost DB_PORT=5432 DB_NAME=… DB_USER=… DB_PASSWORD=…
#   TODO_ENV=development            # poste de développement seulement
#   TODO_SECRET_KEY=…               # `openssl rand -hex 32` ; exigée hors développement
#   TODO_REGISTRATION=open|closed   # closed par défaut
#   TODO_PUBLIC_URL=https://…       # origine attendue des requêtes à cookie

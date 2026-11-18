"""Faux serveur de l'API de l'hébergeur, pour la répétition locale du déploiement (gate
`deploiement`). Il tient les mêmes chemins, les mêmes codes et les mêmes formes de réponse que
ceux que deployer.sh a rencontrés chez l'hébergeur, et il a de VRAIS effets sur la cible jetable,
par trois commandes fournies par la répétition :

  FAUX_CREER_UTILISATEUR  crée le login de la base ($1 : son nom ; mot de passe sur l'entrée standard)
  FAUX_CREER_BASE         crée la base ($1 : son nom, propriété du login du même nom)
  FAUX_REDEMARRER         redémarre le site, comme le fait la plateforme

  FAUX_JETON, FAUX_COMPTE  seuls identifiants admis (tout autre appel reçoit 401)
  FAUX_PORT                port d'écoute, sur 127.0.0.1
  FAUX_JOURNAL             fichier où s'écrit une ligne par appel : « MÉTHODE chemin code ».
                           Jamais un corps, jamais un en-tête : aucun secret n'y entre.

Ce faux serveur prouve que le script tient son contrat ; il ne prouve pas l'hébergeur lui-même."""
import base64
import json
import os
import re
import subprocess
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer

JETON, COMPTE = os.environ["FAUX_JETON"], os.environ["FAUX_COMPTE"]
JOURNAL = os.environ["FAUX_JOURNAL"]
ATTENDU = "Basic " + base64.b64encode(f"{JETON} account={COMPTE}:".encode()).decode()
ETAT = {"/database/user/": [], "/database/": [], "/site/": []}
NUMERO = [1000]


def commande(nom: str, argument: str, entree: str = "") -> bool:
    return subprocess.run(["bash", "-c", os.environ[nom] + ' "$1"', "faux", argument],
                          input=entree.encode(), stdout=subprocess.DEVNULL,
                          stderr=subprocess.DEVNULL).returncode == 0


class Appel(BaseHTTPRequestHandler):
    def repondre(self, code: int, corps=None, lieu: str = "") -> None:
        with open(JOURNAL, "a", encoding="utf-8") as journal:
            journal.write(f"{self.command} {self.path} {code}\n")
        donnees = json.dumps(corps).encode() if corps is not None else b""
        self.send_response(code)
        if lieu:
            self.send_header("Location", lieu)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(donnees)))
        self.end_headers()
        self.wfile.write(donnees)

    def traiter(self) -> None:
        if self.headers.get("Authorization") != ATTENDU:
            return self.repondre(401, {"detail": "Authentication required"})
        if not self.path.startswith("/v1/"):
            return self.repondre(404)
        chemin = self.path[3:]
        taille = int(self.headers.get("Content-Length") or 0)
        corps = json.loads(self.rfile.read(taille)) if taille else {}
        if self.command == "GET" and chemin in ETAT:
            return self.repondre(200, ETAT[chemin])
        redemarrage = re.fullmatch(r"/site/(\d+)/restart/", chemin)
        if self.command == "POST" and redemarrage:
            if not any(s["id"] == int(redemarrage.group(1)) for s in ETAT["/site/"]):
                return self.repondre(404)
            return self.repondre(204 if commande("FAUX_REDEMARRER", redemarrage.group(1)) else 500)
        if self.command == "POST" and chemin in ETAT:
            nom = corps.get("name", "")
            if chemin != "/site/" and any(e["name"] == nom for e in ETAT[chemin]):
                return self.repondre(400, {"name": ["Ce nom est déjà utilisé."]})
            if chemin == "/database/user/":
                if not commande("FAUX_CREER_UTILISATEUR", nom, corps.get("password", "")):
                    return self.repondre(500)
                fiche = {"name": nom, "type": corps.get("type")}
            elif chemin == "/database/":
                if not commande("FAUX_CREER_BASE", nom):
                    return self.repondre(500)
                fiche = {"name": nom, "type": corps.get("type"), "permissions": corps.get("permissions", {})}
            else:
                prises = {a for s in ETAT[chemin] for a in s["addresses"]}
                if prises & set(corps.get("addresses", [])):
                    return self.repondre(400, {"addresses": ["Cette adresse est déjà utilisée."]})
                fiche = {k: v for k, v in corps.items() if k != "annotation"}
            NUMERO[0] += 1
            fiche["id"] = NUMERO[0]
            ETAT[chemin].append(fiche)
            return self.repondre(201, None, f"/v1{chemin}{fiche['id']}/")
        self.repondre(405)

    do_GET = do_POST = do_PATCH = do_PUT = do_DELETE = traiter

    def log_message(self, *_):  # le seul journal est FAUX_JOURNAL
        pass


if __name__ == "__main__":
    HTTPServer(("127.0.0.1", int(os.environ["FAUX_PORT"])), Appel).serve_forever()

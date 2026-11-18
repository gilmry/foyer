"""Appels à l'API de l'hébergeur (alwaysdata) pour deployer.sh et revenir.sh. Bibliothèque standard.

Ce module ne fait que LIRE et CRÉER : il ne modifie ni ne supprime jamais une base, un utilisateur
ou un site. Le seul autre geste est le redémarrage d'un site.

  python3 -I hebergeur.py jeton                        code 0 si un jeton est disponible, 3 sinon
  python3 -I hebergeur.py etat <compte> <instance> <POSTGRESQL|MYSQL> <adresse publique>
        → trois lignes : utilisateur=present|absent, base=present|absent, site=<numéro>|absent
  python3 -I hebergeur.py creer-utilisateur <compte> <instance> <POSTGRESQL|MYSQL>
        le mot de passe arrive par l'ENTRÉE STANDARD, jamais par un argument
  python3 -I hebergeur.py creer-base <compte> <instance> <POSTGRESQL|MYSQL>
  python3 -I hebergeur.py creer-site <compte> <instance> <adresse publique> '<réglages JSON>'
        → le numéro du site créé
  python3 -I hebergeur.py redemarrer <compte> <numéro du site>

Le jeton d'API est lu dans la variable ALWAYSDATA_TOKEN, sinon dans le fichier .env du projet
(KIT_ENV_FICHIER, ignoré par git). Il n'est ni affiché, ni passé en argument. ALWAYSDATA_API
remplace l'adresse de l'API (la répétition locale y met un faux serveur).
La base et son utilisateur s'appellent <compte>_<instance> ; un site est reconnu à son ADRESSE."""
from __future__ import annotations

import base64
import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request

API = os.environ.get("ALWAYSDATA_API", "https://api.alwaysdata.com/v1").rstrip("/")
MARQUE = "créé par deployer.sh"


def lire_jeton() -> str | None:
    jeton = os.environ.get("ALWAYSDATA_TOKEN", "").strip()
    if jeton:
        return jeton
    fichier = os.environ.get("KIT_ENV_FICHIER", "")
    if fichier and os.path.isfile(fichier):
        with open(fichier, encoding="utf-8") as lignes:
            for ligne in lignes:
                if ligne.startswith("ALWAYSDATA_TOKEN="):
                    return ligne.split("=", 1)[1].strip().strip("\"'") or None
    return None


def appel(compte: str, methode: str, chemin: str, corps: dict | None = None) -> tuple[int, str, str]:
    jeton = lire_jeton()
    if not jeton:
        echec("aucun jeton d'API (ALWAYSDATA_TOKEN dans le fichier .env du projet)", 3)
    auth = base64.b64encode(f"{jeton} account={compte}:".encode()).decode()
    requete = urllib.request.Request(
        API + chemin, method=methode,
        data=json.dumps(corps).encode() if corps is not None else None,
        headers={"Authorization": "Basic " + auth, "Content-Type": "application/json",
                 "Accept": "application/json"})
    try:
        with urllib.request.urlopen(requete, timeout=90) as reponse:
            return reponse.status, reponse.headers.get("Location", ""), reponse.read().decode()
    except urllib.error.HTTPError as erreur:
        return erreur.code, "", erreur.read().decode(errors="replace")
    except OSError as erreur:
        echec(f"API de l'hébergeur injoignable : {type(erreur).__name__}")


def echec(message: str, code: int = 1):
    print(f"hebergeur.py : {message}", file=sys.stderr)
    sys.exit(code)


def lister(compte: str, chemin: str) -> list[dict]:
    code, _, texte = appel(compte, "GET", chemin)
    if code != 200:
        echec(f"GET {chemin} : HTTP {code}")
    return json.loads(texte)


def hote_de(adresse: str) -> str:
    hote = urllib.parse.urlsplit(adresse).netloc
    if not hote:
        echec(f"adresse publique invalide : {adresse}")
    return hote


def site_de(compte: str, adresse: str) -> dict | None:
    """Le site qui sert déjà cette adresse, quel que soit son nom (il a pu être créé à la main)."""
    hote = hote_de(adresse)
    for site in lister(compte, "/site/"):
        if any(a.rstrip("/") == hote for a in site.get("addresses", [])):
            return site
    return None


def existe(compte: str, chemin: str, nom: str, moteur: str) -> bool:
    return any(e.get("name") == nom and e.get("type", moteur) == moteur for e in lister(compte, chemin))


def creer(compte: str, chemin: str, corps: dict) -> str:
    code, lieu, texte = appel(compte, "POST", chemin, corps)
    if code != 201:
        # Jamais le corps d'une erreur quand un mot de passe a été envoyé : il pourrait le répéter.
        detail = "" if "password" in corps else " " + texte[:300]
        echec(f"POST {chemin} : HTTP {code}{detail}")
    return lieu.rstrip("/").rsplit("/", 1)[-1]


def main(argv: list[str]) -> None:
    if len(argv) < 2:
        echec(__doc__ or "", 2)
    commande, reste = argv[1], argv[2:]
    if commande == "jeton":
        sys.exit(0 if lire_jeton() else 3)
    if commande == "etat" and len(reste) == 4:
        compte, instance, moteur, adresse = reste
        nom = f"{compte}_{instance}"
        site = site_de(compte, adresse)
        print("utilisateur=" + ("present" if existe(compte, "/database/user/", nom, moteur) else "absent"))
        print("base=" + ("present" if existe(compte, "/database/", nom, moteur) else "absent"))
        print("site=" + (str(site["id"]) if site else "absent"))
    elif commande == "creer-utilisateur" and len(reste) == 3:
        compte, instance, moteur = reste
        mot_de_passe = sys.stdin.read().strip()
        if not mot_de_passe:
            echec("mot de passe vide sur l'entrée standard")
        creer(compte, "/database/user/", {"name": f"{compte}_{instance}", "type": moteur,
                                          "password": mot_de_passe, "annotation": f"{MARQUE} pour {instance}"})
    elif commande == "creer-base" and len(reste) == 3:
        compte, instance, moteur = reste
        nom = f"{compte}_{instance}"
        creer(compte, "/database/", {"name": nom, "type": moteur, "permissions": {nom: "FULL"},
                                     "annotation": f"{MARQUE} pour {instance}"})
    elif commande == "creer-site" and len(reste) == 4:
        compte, instance, adresse, reglages = reste
        corps = json.loads(reglages)
        corps.update({"name": instance, "addresses": [hote_de(adresse) + "/"], "ssl_force": True,
                      "annotation": f"{MARQUE} pour {instance}"})
        print(creer(compte, "/site/", corps))
    elif commande == "redemarrer" and len(reste) == 2:
        compte, site = reste
        code, _, _ = appel(compte, "POST", f"/site/{int(site)}/restart/")
        if code != 204:
            echec(f"redémarrage du site {int(site)} : HTTP {code}")
    else:
        echec(__doc__ or "", 2)


if __name__ == "__main__":
    main(sys.argv)

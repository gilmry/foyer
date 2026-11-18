"""Client de la sonde du pont : interroge l'application-sonde servie par uWSGI et rend, en JSON,
ce qui passe et ce qui ne passe pas. Bibliothèque standard seulement (tourne sur la cible)."""
from __future__ import annotations

import http.client
import json
import socket
import sys
import time

HOTE, PORT = sys.argv[1], int(sys.argv[2])
DELAI = 6.0


def get(chemin: str):
    conn = http.client.HTTPConnection(HOTE, PORT, timeout=DELAI)
    try:
        conn.request("GET", chemin)
        rep = conn.getresponse()
        return rep.status, rep.read()
    finally:
        conn.close()


def essai(fn):
    try:
        return fn()
    except (TimeoutError, socket.timeout):
        return "délai dépassé"
    except (OSError, http.client.HTTPException) as exc:
        return f"erreur : {type(exc).__name__}"


def etat():
    status, corps = get("/etat")
    return json.loads(corps) if status == 200 else f"HTTP {status}"


def flux():
    conn = http.client.HTTPConnection(HOTE, PORT, timeout=DELAI)
    try:
        debut = time.monotonic()
        conn.request("GET", "/flux")
        rep = conn.getresponse()
        arrivees = []
        while True:
            ligne = rep.fp.readline()
            if not ligne:
                break
            if b"morceau" in ligne:
                arrivees.append(round(time.monotonic() - debut, 2))
        return arrivees
    finally:
        conn.close()


def websocket():
    with socket.create_connection((HOTE, PORT), timeout=DELAI) as s:
        s.sendall(
            b"GET /ws HTTP/1.1\r\nHost: sonde\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n"
            b"Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\nSec-WebSocket-Version: 13\r\n\r\n")
        return s.recv(200).split(b"\r\n", 1)[0].decode("latin-1")


resultat: dict = {}
premier = essai(etat)
resultat["repond"] = isinstance(premier, dict)
if resultat["repond"]:
    resultat["lifespan"] = premier["lifespan"]
    time.sleep(0.6)
    second = essai(etat)
    resultat["tache_de_fond_du_lifespan"] = isinstance(second, dict) and second["tics"] > premier["tics"]
    # Dix requêtes de suite : un processus qui répond une fois puis se fige se voit ici.
    suite = [essai(etat) for _ in range(10)]
    resultat["repond_dix_fois"] = all(isinstance(r, dict) for r in suite)
    resultat["processus_vus"] = len({r["pid"] for r in suite if isinstance(r, dict)})
    arrivees = essai(flux)
    resultat["flux_arrivees_s"] = arrivees
    resultat["flux_au_fil_de_l_eau"] = isinstance(arrivees, list) and len(arrivees) == 4 \
        and arrivees[-1] - arrivees[0] >= 1.0
    lance = essai(lambda: get("/fond")[0])
    time.sleep(1.2)
    apres = [essai(etat) for _ in range(6)]
    resultat["tache_apres_reponse"] = lance == 200 and any(isinstance(r, dict) and r["apres_reponse"] for r in apres)
    resultat["websocket"] = essai(websocket)
    # Un fil lancé par l'application avance-t-il pendant que le serveur ne reçoit rien ?
    # uWSGI ne répartit pas les requêtes à tour de rôle : on relève CHAQUE processus joignable
    # avant le repos, puis on compare au premier processus déjà relevé qui répond après.
    avant = {}
    for _ in range(12):
        r = essai(etat)
        if isinstance(r, dict):
            avant[r["pid"]] = r["fil_tics"]
    time.sleep(1.0)
    delta = None
    for _ in range(12):
        apres_repos = essai(etat)
        if isinstance(apres_repos, dict) and apres_repos["pid"] in avant:
            delta = apres_repos["fil_tics"] - avant[apres_repos["pid"]]
            break
    resultat["fil_tics_pendant_1s_de_repos"] = delta
    resultat["fils_actifs_au_repos"] = delta is not None and delta >= 10
else:
    resultat["detail"] = premier
print(json.dumps(resultat, ensure_ascii=False))

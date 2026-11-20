"""Empreintes — bibliothèque standard seulement (couche pure).

Un jeton est tiré au hasard (256 bits) : une empreinte rapide suffit, là où un mot de passe exige
Argon2id. HMAC-SHA-256 avec la clé de l'instance plutôt que SHA-256 nu : une copie de la base ne
permet ni de fabriquer une empreinte valide, ni de retrouver quels courriels ont été essayés."""
from __future__ import annotations

import hashlib
import hmac


def fingerprint(secret_key: str, value: str) -> str:
    return hmac.new(secret_key.encode("utf-8"), value.encode("utf-8"), hashlib.sha256).hexdigest()

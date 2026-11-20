# Cible jetable de la répétition de déploiement : ce qu'un hébergeur infogéré donne à voir.
# Debian 12 (glibc 2.36), Python 3.12 au chemin où l'hébergeur le fournit, uWSGI 2.0.x (montage B),
# un compte sans privilège joignable par SSH. Les dépendances du kit n'y sont PAS : elles arrivent
# par le déploiement, déjà préparées. Base PUBLIQUE (python:3.12-slim-bookworm).
FROM python:3.12-slim-bookworm
RUN apt-get update && apt-get install -y --no-install-recommends openssh-server procps openssl ca-certificates libexpat1 \
    && rm -rf /var/lib/apt/lists/* && mkdir -p /run/sshd \
    && useradd -m -s /bin/bash repet && mkdir -p /home/repet/.ssh && chmod 700 /home/repet/.ssh \
    && chown -R repet:repet /home/repet/.ssh \
    && mkdir -p /usr/alwaysdata/python/3.12/bin /usr/alwaysdata/uwsgi/bin \
    && ln -s /usr/local/bin/python3.12 /usr/alwaysdata/python/3.12/bin/python \
    && pip install --no-cache-dir --disable-pip-version-check --root-user-action=ignore pyuwsgi==2.0.30.post1 \
    && ln -s /usr/local/bin/uwsgi /usr/alwaysdata/uwsgi/bin/uwsgi
CMD ["/usr/sbin/sshd", "-D", "-e", "-p", "12223", "-o", "ListenAddress=127.0.0.1", "-o", "PasswordAuthentication=no"]

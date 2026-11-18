# Cible jetable de la répétition de déploiement : ce qu'un hébergeur infogéré donne à voir.
# Debian 12 (glibc 2.36), un compte sans privilège joignable par SSH, et rien d'autre : ni Rust,
# ni compilateur. Base PUBLIQUE (debian:12-slim).
FROM debian:12-slim
RUN apt-get update && apt-get install -y --no-install-recommends openssh-server procps ca-certificates \
    && rm -rf /var/lib/apt/lists/* && mkdir -p /run/sshd \
    && useradd -m -s /bin/bash repet && mkdir -p /home/repet/.ssh && chmod 700 /home/repet/.ssh \
    && chown -R repet:repet /home/repet/.ssh
CMD ["/usr/sbin/sshd", "-D", "-e", "-p", "12222", "-o", "ListenAddress=127.0.0.1", "-o", "PasswordAuthentication=no"]

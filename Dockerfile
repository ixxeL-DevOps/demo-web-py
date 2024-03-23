# Utilisez une image Python basée sur Alpine Linux comme image de base
FROM python:3.12-alpine3.19

LABEL maintainer="fredspiers@gmail.com"
LABEL org.opencontainers.image.authors="F.SPIERS"
LABEL org.opencontainers.image.base.name="python:3.12-alpine3.19"

ENV TZ="Europe/Paris"

# Installez les dépendances système nécessaires
RUN --mount=type=cache,target=/var/cache/apk \
    apk update --no-cache && \
    apk upgrade --no-cache && \
    apk add --no-cache --update \
    build-base \
    libressl-dev \
    musl-dev \
    libffi-dev    

# Définir le répertoire de travail dans le conteneur
WORKDIR /app

# Copier les fichiers nécessaires dans le conteneur
COPY app/ .

# Installer les dépendances Python
RUN pip install --no-cache-dir -r requirements.txt

# Exposer le port sur lequel Uvicorn s'exécute
EXPOSE 8080

# Définir la commande par défaut à exécuter lorsqu'un conteneur est démarré
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8080"]

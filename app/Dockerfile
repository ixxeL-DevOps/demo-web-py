FROM python:3.12-alpine3.19

LABEL maintainer="fredspiers@gmail.com"
LABEL org.opencontainers.image.authors="F.SPIERS"
LABEL org.opencontainers.image.base.name="python:3.12-alpine3.19"

ENV TZ="Europe/Paris"

RUN --mount=type=cache,target=/var/cache/apk \
    apk update --no-cache && \
    apk upgrade --no-cache && \
    apk add --no-cache --update \
    build-base \
    libressl-dev \
    musl-dev \
    libffi-dev    

WORKDIR /app

COPY . .

RUN pip install --no-cache-dir -r requirements.txt

EXPOSE 8080

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8080", "--log-level", "info"]

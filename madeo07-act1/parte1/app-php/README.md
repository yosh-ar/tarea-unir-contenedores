# app-php

Microservicio HTTP mínimo en PHP para la Actividad 1 de Contenedores (UNIR).

- **Lenguaje / runtime:** PHP 8.3 CLI (servidor web embebido).
- **Imagen base:** `php:8.3-cli-alpine3.20` (tag pinado, no `latest`).
- **Puerto:** 8081.
- **Rutas:**
  - `GET /` — HTML con nombre, lenguaje y versión, hostname del contenedor y fecha/hora.
  - `GET /health` — `{"status":"ok","language":"php"}`.

## Build local (arm64)

```bash
docker buildx build --platform linux/arm64 --load \
  -t coste123/madeo07-php:1.0.0 -t coste123/madeo07-php:latest .
```

## Run

```bash
docker run -d --name app-php -p 8081:8081 coste123/madeo07-php:1.0.0
curl -s http://localhost:8081/
curl -s http://localhost:8081/health
```

## Push multi-arch

```bash
docker buildx build --platform linux/amd64,linux/arm64 --push \
  -t coste123/madeo07-php:1.0.0 -t coste123/madeo07-php:latest .
```

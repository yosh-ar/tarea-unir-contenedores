# app-dart

Microservicio HTTP mínimo en Dart (compilado AOT) para la Actividad 1 de Contenedores (UNIR).

- **Lenguaje / runtime:** Dart 3.5.4 (compilado AOT).
- **Imagen base de build:** `dart:3.5.4` (tag pinado).
- **Imagen base de runtime:** `debian:bookworm-slim` (necesaria por glibc; Alpine/musl no es compatible con el binario AOT de Dart).
- **Puerto:** 8083.
- **Rutas:**
  - `GET /` — HTML con nombre, lenguaje y versión, hostname del contenedor y fecha/hora.
  - `GET /health` — `{"status":"ok","language":"dart"}`.

## Build local (arm64)

```bash
docker buildx build --platform linux/arm64 --load \
  -t coste123/madeo07-dart:1.0.0 -t coste123/madeo07-dart:latest .
```

## Run

```bash
docker run -d --name app-dart -p 8083:8083 coste123/madeo07-dart:1.0.0
curl -s http://localhost:8083/
curl -s http://localhost:8083/health
```

## Push multi-arch

```bash
docker buildx build --platform linux/amd64,linux/arm64 --push \
  -t coste123/madeo07-dart:1.0.0 -t coste123/madeo07-dart:latest .
```

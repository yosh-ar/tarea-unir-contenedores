# app-ruby

Microservicio HTTP mínimo en Ruby para la Actividad 1 de Contenedores (UNIR).

- **Lenguaje / runtime:** Ruby 3.3 + gema `webrick` 1.8.1.
- **Imagen base:** `ruby:3.3-alpine3.20` (tag pinado).
- **Puerto:** 8082.
- **Rutas:**
  - `GET /` — HTML con nombre, lenguaje y versión, hostname del contenedor y fecha/hora.
  - `GET /health` — `{"status":"ok","language":"ruby"}`.

## Build local (arm64)

```bash
docker buildx build --platform linux/arm64 --load \
  -t coste123/madeo07-ruby:1.0.0 -t coste123/madeo07-ruby:latest .
```

## Run

```bash
docker run -d --name app-ruby -p 8082:8082 coste123/madeo07-ruby:1.0.0
curl -s http://localhost:8082/
curl -s http://localhost:8082/health
```

## Push multi-arch

```bash
docker buildx build --platform linux/amd64,linux/arm64 --push \
  -t coste123/madeo07-ruby:1.0.0 -t coste123/madeo07-ruby:latest .
```

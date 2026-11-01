# tarea-unir-contenedores

Actividad 1 de la asignatura **Contenedores** de la Maestría en DevOps (UNIR).

El repositorio contiene tres microservicios HTTP mínimos escritos en lenguajes distintos (**PHP**, **Ruby** y **Dart**), cada uno con su propio `Dockerfile`, publicados como imágenes multi-arquitectura (`linux/amd64` y `linux/arm64`) en Docker Hub bajo el usuario `coste123`.

Cada microservicio expone dos rutas:

- `GET /` — HTML con el nombre de la app, el lenguaje y su versión, el hostname del contenedor y la fecha/hora en UTC.
- `GET /health` — JSON `{"status":"ok","language":"…"}`.

---

## Estructura del repositorio

```
tarea-unir-contenedores/
├── README.md
├── .gitignore
└── madeo07-act1/
    ├── capturas/            # Capturas de pantalla de la verificación
    │   ├── cap02-docker-images.png
    │   ├── cap03-docker-ps.png
    │   ├── cap04-tres-apps.png
    │   ├── cap05-imagetools.png
    │   ├── cap06-dockerhub.png
    │   ├── cap07-dockerhub-tags.png
    │   └── cap08-docker-pull.png
    └── parte1/
        ├── app-php/         # index.php, Dockerfile, .dockerignore, README.md
        ├── app-ruby/        # server.rb, Dockerfile, .dockerignore, README.md
        ├── app-dart/        # pubspec.yaml, bin/server.dart, Dockerfile, .dockerignore, README.md
        ├── run-all.sh       # Reconstruye, levanta y verifica las tres apps en local
        └── EVIDENCIAS.md    # Bitácora de la ejecución con salidas reales
```

---

## Las tres apps

| App       | Lenguaje / versión | Imagen base                                                         | Puerto | Imagen en Docker Hub                                                                 |
|-----------|--------------------|---------------------------------------------------------------------|--------|--------------------------------------------------------------------------------------|
| app-php   | PHP 8.3.22 (CLI)   | `php:8.3-cli-alpine3.20`                                            | 8081   | [`coste123/madeo07-php`](https://hub.docker.com/r/coste123/madeo07-php)             |
| app-ruby  | Ruby 3.3.8 + WEBrick 1.8.1 | `ruby:3.3-alpine3.20`                                       | 8082   | [`coste123/madeo07-ruby`](https://hub.docker.com/r/coste123/madeo07-ruby)           |
| app-dart  | Dart 3.5.4 (AOT)   | `dart:3.5.4` (builder) + `debian:bookworm-slim` (runtime)           | 8083   | [`coste123/madeo07-dart`](https://hub.docker.com/r/coste123/madeo07-dart)           |

Las tres imágenes se publicaron con los tags `1.0.0` y `latest`, ambos apuntando al mismo *image index* OCI con manifests nativos para `linux/amd64` y `linux/arm64`.

---

## Cómo ejecutar las apps

### Opción A — Desde Docker Hub (sin clonar el repositorio)

Las imágenes están publicadas en Docker Hub, así que basta con `docker pull` + `docker run`:

```bash
docker pull coste123/madeo07-php:latest
docker pull coste123/madeo07-ruby:latest
docker pull coste123/madeo07-dart:latest

docker run -d --name app-php  -p 8081:8081 coste123/madeo07-php:latest
docker run -d --name app-ruby -p 8082:8082 coste123/madeo07-ruby:latest
docker run -d --name app-dart -p 8083:8083 coste123/madeo07-dart:latest
```

Verificación rápida:

```bash
curl -s http://localhost:8081/health   # {"status":"ok","language":"php"}
curl -s http://localhost:8082/health   # {"status":"ok","language":"ruby"}
curl -s http://localhost:8083/health   # {"status":"ok","language":"dart"}
```

Y en el navegador: <http://localhost:8081>, <http://localhost:8082>, <http://localhost:8083>.

### Opción B — Desde el código (clonando el repositorio)

Requiere Docker Desktop con `buildx` habilitado.

```bash
git clone https://github.com/yosh-ar/tarea-unir-contenedores.git
cd tarea-unir-contenedores/madeo07-act1/parte1
./run-all.sh
```

El script `run-all.sh`:

1. Elimina los contenedores previos (`app-php`, `app-ruby`, `app-dart`), si existen.
2. Reconstruye las tres imágenes en local con `docker buildx build` (por defecto `linux/arm64`; se puede cambiar con `PLATFORM_LOCAL=linux/amd64 ./run-all.sh`).
3. Levanta los tres contenedores con `-d`, `--name` y `-p`.
4. Verifica `/health` con `curl` en cada uno y muestra `docker ps` y `docker images` al finalizar.

---

## Documentación de la actividad

- **[`madeo07-act1/parte1/EVIDENCIAS.md`](madeo07-act1/parte1/EVIDENCIAS.md)** — bitácora completa con la salida real de cada paso: entorno, build local, push multi-arquitectura, verificación de manifests y despliegue desde el registro.
- **[`madeo07-act1/capturas/`](madeo07-act1/capturas/)** — capturas de pantalla referenciadas desde `EVIDENCIAS.md`.

---

## Parte 2 — Docker Compose

En construcción.

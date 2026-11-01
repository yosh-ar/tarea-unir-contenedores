# EVIDENCIAS — Actividad 1 (Contenedores, UNIR)

> Autor: `coste123` (josuearguetaorozco20@gmail.com)
> Equipo: MacBook Pro Apple Silicon (arm64), macOS 26.0.1
> Fecha de la ejecución: 2026-11-01
> Docker Desktop 4.36.0 — Engine 27.3.1 (linux/arm64)
> `docker buildx` v0.18.0 — builder `desktop-linux` con soporte multi-plataforma

Este documento registra, en orden cronológico y con **salida real**, cada paso de la Actividad 1. Las anotaciones `[CAPTURA]` indican los puntos en los que deben tomarse screenshots para el informe.

Estructura entregada:

```
madeo07-act1/
└── parte1/
    ├── app-php/      (index.php, Dockerfile, .dockerignore, README.md)
    ├── app-ruby/     (server.rb, Dockerfile, .dockerignore, README.md)
    ├── app-dart/     (pubspec.yaml, bin/server.dart, Dockerfile, .dockerignore, README.md)
    ├── run-all.sh
    └── EVIDENCIAS.md
```

---

## 0. Evaluación del entorno

### 0.1 Versión de Docker

```bash
$ docker version
Client:
 Version:           27.3.1
 API version:       1.47
 Go version:        go1.22.7
 Git commit:        ce12230
 Built:             Fri Sep 20 11:38:18 2024
 OS/Arch:           darwin/arm64
 Context:           desktop-linux

Server: Docker Desktop 4.36.0 (175267)
 Engine:
  Version:          27.3.1
  OS/Arch:          linux/arm64
  ...
```

### 0.2 buildx y builder activo

```bash
$ docker buildx version
github.com/docker/buildx v0.18.0-desktop.2 44b68677dee147502ef0be4cbead34310e44d1f6

$ docker buildx ls
NAME/NODE           DRIVER/ENDPOINT     STATUS    BUILDKIT   PLATFORMS
default             docker
 \_ default          \_ default         running   v0.16.0    linux/amd64 (+2), linux/arm64, linux/ppc64le, linux/s390x, (4 more)
desktop-linux*      docker
 \_ desktop-linux    \_ desktop-linux   running   v0.16.0    linux/amd64 (+2), linux/arm64, linux/ppc64le, linux/s390x, (4 more)
```

> El builder `desktop-linux` soporta nativamente `linux/arm64` y, vía emulación QEMU, `linux/amd64`. Esto es lo que permite publicar imágenes multi-arquitectura.

### 0.3 Estado antes de empezar

```bash
$ docker ps -a
CONTAINER ID   IMAGE           COMMAND                  CREATED       STATUS      PORTS                      NAMES
5cab517537a5   postgres:18.6   "docker-entrypoint.s…"   6 weeks ago   Up 5 days   127.0.0.1:5439->5432/tcp   anota-db

$ docker images
REPOSITORY            TAG       IMAGE ID       CREATED         SIZE
postgres              18.6      1957b2ff3137   2 months ago    666MB
testcontainers/ryuk   0.14.0    7c1a8a9a47c7   13 months ago   4.26MB

$ lsof -i :8081 -i :8082 -i :8083 || echo "ports free"
ports free
```

Puertos 8081, 8082 y 8083 **libres**. El contenedor `anota-db` no interfiere (puerto 5439).

### 0.4 Decisión de estrategia de build

`docker buildx --load` solo admite **una plataforma por vez** (limitación de BuildKit). Al estar en arm64 nativo:

- **Local:** `buildx build --platform linux/arm64 --load` → rápido, sin QEMU.
- **Push final:** `buildx build --platform linux/amd64,linux/arm64 --push` → compila ambas arquitecturas y publica el *manifest list* directamente al registro.

---

## 1. App PHP — ciclo completo (paso a paso para el informe)

Esta es la app que documento con mayor detalle. Las otras dos siguen exactamente el mismo patrón.

### 1.1 Código fuente (`app-php/index.php`)

Front-controller único que distingue entre `/` (HTML) y `/health` (JSON):

```php
<?php
$uri = parse_url($_SERVER['REQUEST_URI'] ?? '/', PHP_URL_PATH);
$lang_version = 'PHP ' . PHP_VERSION;
$hostname = gethostname() ?: 'unknown';
$now = gmdate('Y-m-d H:i:s');

if ($uri === '/health') {
    header('Content-Type: application/json; charset=utf-8');
    echo json_encode(['status' => 'ok', 'language' => 'php']);
    return true;
}
// (… renderiza HTML con nombre, lenguaje y versión, hostname y fecha UTC)
```

### 1.2 Dockerfile (`app-php/Dockerfile`)

Puntos clave:

| Instrucción | Qué hace / por qué |
|---|---|
| `FROM php:8.3-cli-alpine3.20` | Base oficial pinada (PHP 8.3 + Alpine 3.20). **No `latest`** → builds reproducibles. |
| `LABEL org.opencontainers.image.*` | Metadatos OCI (title, description, source, version, authors, licenses). Visibles en `docker inspect` y Docker Hub. |
| `WORKDIR /app` | Fija el directorio de trabajo. |
| `COPY index.php /app/index.php` | Solo el front-controller → caché de capas óptima. |
| `RUN addgroup -S app && adduser -S …` | Crea un usuario de sistema sin shell → el proceso **no corre como root** (CIS Docker Benchmark 4.1). |
| `EXPOSE 8081` | Documenta el puerto; necesario para `-P`. |
| `HEALTHCHECK … wget --spider /health` | `wget` viene con busybox/Alpine → sin dependencias extra. |
| `USER app` | A partir de aquí, usuario sin privilegios. |
| `CMD ["php", "-S", "0.0.0.0:8081", "-t", "/app", "/app/index.php"]` | Servidor web embebido de PHP; `/app/index.php` actúa como router. |

### 1.3 Build local arm64

```bash
$ cd madeo07-act1/parte1/app-php
$ docker buildx build --platform linux/arm64 --load \
    -t coste123/madeo07-php:1.0.0 \
    -t coste123/madeo07-php:latest .
```

### 1.4 Verificación de buenas prácticas (sobre la imagen publicada)

```bash
$ docker exec app-php id
uid=100(app) gid=101(app) groups=101(app)           # NO root

$ docker inspect --format='{{.Config.User}}' coste123/madeo07-php:1.0.0
app

$ docker inspect --format='{{.Config.Healthcheck.Test}} | interval={{.Config.Healthcheck.Interval}} timeout={{.Config.Healthcheck.Timeout}}' coste123/madeo07-php:1.0.0
[CMD-SHELL wget -q --spider http://127.0.0.1:8081/health || exit 1] | interval=15s timeout=3s

$ docker inspect --format='{{json .State.Health.Status}}' app-php
"healthy"

$ docker inspect --format='{{range $k,$v := .Config.Labels}}{{$k}}={{$v}}{{"\n"}}{{end}}' coste123/madeo07-php:1.0.0
org.opencontainers.image.authors=coste123 <josuearguetaorozco20@gmail.com>
org.opencontainers.image.description=Microservicio HTTP en PHP para la Actividad 1 de Contenedores (UNIR)
org.opencontainers.image.licenses=MIT
org.opencontainers.image.source=https://hub.docker.com/r/coste123/madeo07-php
org.opencontainers.image.title=madeo07-php
org.opencontainers.image.version=1.0.0
```

---

## 2. Push multi-arquitectura a Docker Hub (ejecutado)

### 2.1 Comando ejecutado por app

```bash
# PHP
cd madeo07-act1/parte1/app-php
docker buildx build --platform linux/amd64,linux/arm64 --push \
  -t coste123/madeo07-php:1.0.0 -t coste123/madeo07-php:latest .

# Ruby
cd madeo07-act1/parte1/app-ruby
docker buildx build --platform linux/amd64,linux/arm64 --push \
  -t coste123/madeo07-ruby:1.0.0 -t coste123/madeo07-ruby:latest .

# Dart
cd madeo07-act1/parte1/app-dart
docker buildx build --platform linux/amd64,linux/arm64 --push \
  -t coste123/madeo07-dart:1.0.0 -t coste123/madeo07-dart:latest .
```

### 2.2 Verificación de manifests multi-arch (`docker buildx imagetools inspect`)

**PHP 1.0.0:**

```
Name:      docker.io/coste123/madeo07-php:1.0.0
MediaType: application/vnd.oci.image.index.v1+json
Digest:    sha256:4e0608ffefafb27bb80e6f23b1245c66093fe93325bd8382d503f8f5df5c2c14

Manifests:
  Platform:  linux/amd64      sha256:1dc7dc4c29efd261526686f0469930883d388ede4e63aa274c95e0ef3f5cd612
  Platform:  linux/arm64      sha256:0445d5f1bb7785d4946b5860698324a67ec88fcb2ef816b8e4ef0be2e5315a3b
  Platform:  unknown/unknown  sha256:b94927a69e88e56d491371449d85ab854478aef91fa6e9e190b058f3d19ea1aa (attestation)
  Platform:  unknown/unknown  sha256:403f70a3033fded75650e95156e1417fdad29435faa7235df3805d4268603cef (attestation)
```

**Ruby 1.0.0:**

```
Name:      docker.io/coste123/madeo07-ruby:1.0.0
MediaType: application/vnd.oci.image.index.v1+json
Digest:    sha256:d57918a72c53ec37e47786de7f65352acfe8640dc95813602de3a4ce5dc50b4e

Manifests:
  Platform:  linux/amd64      sha256:6ddb342eb5272617db147f014abd8fcb1994c00512ea91e4e4c0d5b5b3483c53
  Platform:  linux/arm64      sha256:f51193f7449551cd6cc6a0c11bd8d64b85e21004428fdd8af7933f9723dc2730
  Platform:  unknown/unknown  sha256:7885c4a1a4a37e53a785a010e4b5382c6a8d4b45ed19849041d67e30939b2ae8 (attestation)
  Platform:  unknown/unknown  sha256:70530acc71afa80c71ea80b43296941723d1cd102eb52401d3cd0405f1ac5109 (attestation)
```

**Dart 1.0.0:**

```
Name:      docker.io/coste123/madeo07-dart:1.0.0
MediaType: application/vnd.oci.image.index.v1+json
Digest:    sha256:5f47e1581e3a8c2e70f7a5f3031638ff42dfe8bf5f5d299eab7a4e1537eab401

Manifests:
  Platform:  linux/amd64      sha256:6b0e730051b135130031089f8fe5c91c4c2fad6b643926bd92f890e0bd652bad
  Platform:  linux/arm64      sha256:1d218ac5589bf6ccf09e6e0c34119610fbe706846189f385ed2611308b1dc483
  Platform:  unknown/unknown  sha256:f86a5a2d224fc1223dc5b68276adc7e64c1dfbba8a88b6130119baf390d36443 (attestation)
  Platform:  unknown/unknown  sha256:c98154844aed889971f2ecbb92913579e688250966ebee7aea10a57dd8bb3506 (attestation)
```

Los tags `:latest` apuntan a los **mismos digests** que `:1.0.0` en las tres apps (verificado con `docker buildx imagetools inspect coste123/madeo07-*:latest` → mismo `Digest` del *image index* y mismos digests de `linux/amd64` y `linux/arm64`).

**[CAPTURA 1]** Terminal con `docker buildx imagetools inspect coste123/madeo07-php:1.0.0` mostrando los dos manifests nativos.

**[CAPTURA 2]** Página de Docker Hub con las tres imágenes `coste123/madeo07-{php,ruby,dart}` listadas, mostrando los tags `1.0.0` y `latest`:

- https://hub.docker.com/r/coste123/madeo07-php
- https://hub.docker.com/r/coste123/madeo07-ruby
- https://hub.docker.com/r/coste123/madeo07-dart

---

## 3. Despliegue desde el registro (pull + run)

Para demostrar que los contenedores corren efectivamente **desde las imágenes publicadas en Docker Hub** (no desde un build local con el mismo nombre), limpié el entorno y volví a desplegar tirando de las imágenes del registro.

### 3.1 Limpieza previa

```bash
$ docker rm -f app-php app-ruby app-dart
app-php
app-ruby
app-dart

$ docker rmi coste123/madeo07-php:1.0.0 coste123/madeo07-php:latest \
             coste123/madeo07-ruby:1.0.0 coste123/madeo07-ruby:latest \
             coste123/madeo07-dart:1.0.0 coste123/madeo07-dart:latest
Untagged: coste123/madeo07-php:1.0.0
Untagged: coste123/madeo07-php:latest
Deleted: sha256:4e0608ffefafb27bb80e6f23b1245c66093fe93325bd8382d503f8f5df5c2c14
Untagged: coste123/madeo07-ruby:1.0.0
Untagged: coste123/madeo07-ruby:latest
Deleted: sha256:d57918a72c53ec37e47786de7f65352acfe8640dc95813602de3a4ce5dc50b4e
Untagged: coste123/madeo07-dart:1.0.0
Untagged: coste123/madeo07-dart:latest
Deleted: sha256:5f47e1581e3a8c2e70f7a5f3031638ff42dfe8bf5f5d299eab7a4e1537eab401

$ docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.Size}}" | grep -E "coste123|REPOSITORY"
REPOSITORY            TAG       IMAGE ID       SIZE
# (vacío: no quedan imágenes coste123/madeo07-*)
```

### 3.2 `docker pull` desde Docker Hub

```bash
$ docker pull coste123/madeo07-php:1.0.0
1.0.0: Pulling from coste123/madeo07-php
...
Digest: sha256:4e0608ffefafb27bb80e6f23b1245c66093fe93325bd8382d503f8f5df5c2c14
Status: Downloaded newer image for coste123/madeo07-php:1.0.0
docker.io/coste123/madeo07-php:1.0.0

$ docker pull coste123/madeo07-ruby:1.0.0
...
Digest: sha256:d57918a72c53ec37e47786de7f65352acfe8640dc95813602de3a4ce5dc50b4e
Status: Downloaded newer image for coste123/madeo07-ruby:1.0.0

$ docker pull coste123/madeo07-dart:1.0.0
...
Digest: sha256:5f47e1581e3a8c2e70f7a5f3031638ff42dfe8bf5f5d299eab7a4e1537eab401
Status: Downloaded newer image for coste123/madeo07-dart:1.0.0
```

Los tres digests coinciden exactamente con los *image index* publicados en la sección 2.2 → es la **misma imagen multi-arch** que subimos.

### 3.3 Imágenes locales tras el pull

```bash
$ docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.Size}}" | grep -E "coste123|REPOSITORY"
REPOSITORY              TAG       IMAGE ID       SIZE
coste123/madeo07-dart   1.0.0     5f47e1581e3a   166MB
coste123/madeo07-ruby   1.0.0     d57918a72c53   125MB
coste123/madeo07-php    1.0.0     4e0608ffefaf   137MB
```

### 3.4 `docker run` de los tres contenedores

```bash
$ docker run -d --name app-php  -p 8081:8081 coste123/madeo07-php:1.0.0
dd86ea78b39e19e4da1a62183730d1afc8832625ad70642aeb4b46be675453dc

$ docker run -d --name app-ruby -p 8082:8082 coste123/madeo07-ruby:1.0.0
787c17c0d033c5840e6fc3c1d06d230b45c2937df500d2f2dccab9a4bdcd940b

$ docker run -d --name app-dart -p 8083:8083 coste123/madeo07-dart:1.0.0
e940365ab692a029368a81dee88bb60ca01ce894840de925f562dd159acf93b2
```

### 3.5 `docker ps` — imagen nombrada y `(healthy)` en los tres

```bash
$ docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"
NAMES      IMAGE                         STATUS                    PORTS
app-dart   coste123/madeo07-dart:1.0.0   Up 10 seconds (healthy)   0.0.0.0:8083->8083/tcp
app-ruby   coste123/madeo07-ruby:1.0.0   Up 11 seconds (healthy)   0.0.0.0:8082->8082/tcp
app-php    coste123/madeo07-php:1.0.0    Up 12 seconds (healthy)   0.0.0.0:8081->8081/tcp
anota-db   postgres:18.6                 Up 5 days                 127.0.0.1:5439->5432/tcp
```

> La columna `IMAGE` muestra el **nombre completo** `coste123/madeo07-<lenguaje>:1.0.0` (no un hash), lo que prueba que el contenedor está instanciado a partir de la imagen del registro.

**[CAPTURA 3]** Terminal con el `docker ps` anterior.

### 3.6 Smoke test `/health` y `/`

```bash
$ curl -s http://localhost:8081/health; echo
{"status":"ok","language":"php"}

$ curl -s http://localhost:8082/health; echo
{"status":"ok","language":"ruby"}

$ curl -s http://localhost:8083/health; echo
{"status":"ok","language":"dart"}
```

Fragmentos reales del HTML (`GET /`) por app:

```
PHP :  <code>PHP 8.3.22</code>  …  <code>dd86ea78b39e</code>  …  <code>2026-11-01 19:13:45</code>
Ruby:  <code>Ruby 3.3.8 (p144)</code>  …  <code>787c17c0d033</code>  …  <code>2026-11-01 19:13:46</code>
Dart:  <code>Dart 3.5.4</code>  …  <code>e940365ab692</code>  …  <code>2026-11-01 19:13:47</code>
```

Las tres apps muestran la fecha unificada en formato `YYYY-MM-DD HH:MM:SS` con la etiqueta **"Fecha y hora del servidor (UTC)"**.

**[CAPTURA 4]** Tres pestañas de navegador abiertas en:

- `http://localhost:8081/` (PHP)
- `http://localhost:8082/` (Ruby)
- `http://localhost:8083/` (Dart)

### 3.7 Confirmación de **no-root** en los tres

```bash
$ docker exec app-php  id   # uid=100(app) gid=101(app) groups=101(app)
$ docker exec app-ruby id   # uid=100(app) gid=101(app) groups=101(app)
$ docker exec app-dart id   # uid=999(app) gid=999(app) groups=999(app)
```

### 3.8 Health status reportado por el engine

```bash
$ docker inspect --format='{{json .State.Health.Status}}' app-php
"healthy"
$ docker inspect --format='{{json .State.Health.Status}}' app-ruby
"healthy"
$ docker inspect --format='{{json .State.Health.Status}}' app-dart
"healthy"
```

### 3.9 Log del proceso Dart (confirma binario AOT corriendo)

```bash
$ docker logs app-dart
app-dart listening on 0.0.0.0:8083
```

---

## 4. Script `run-all.sh` (reconstruir + levantar + verificar)

Uso:

```bash
$ cd madeo07-act1/parte1
$ ./run-all.sh
```

El script:

1. Elimina (si existen) los contenedores `app-php`, `app-ruby`, `app-dart`.
2. Reconstruye las tres imágenes con `buildx build --platform linux/arm64 --load` y las etiqueta como `:1.0.0` y `:latest`.
3. Lanza los tres contenedores con `-d`, `--name` y `-p`.
4. Lanza `curl /health` contra cada uno y muestra el código HTTP y el cuerpo.
5. Imprime `docker ps` y `docker images` filtrado.

> La plataforma de build local se puede cambiar con la variable de entorno `PLATFORM_LOCAL=linux/arm64/v8 ./run-all.sh` si fuera necesario.

---

## 5. Autenticación en Docker Hub

El usuario inició sesión mediante **Docker Desktop → Sign in** (flujo browser-based con Google + Google Authenticator). Las credenciales quedan guardadas en el llavero de macOS vía `credsStore: desktop`, por lo que la CLI las usa automáticamente para el push sin necesidad de ejecutar `docker login` interactivo con token.

Al no exponer el token en terminal, se evita que quede grabado en el historial de la shell.

---

## 6. Tabla resumen

> Los tamaños locales son el tamaño del *image unpacked* en arm64 reportado por `docker images`. En Docker Hub se verá además el tamaño comprimido por plataforma.

| App | Lenguaje / versión | Imagen base | Puerto | Tamaño local (arm64) | Image ID (arm64) | URL en Docker Hub |
|---|---|---|---|---|---|---|
| app-php  | PHP 8.3.22 (CLI) | `php:8.3-cli-alpine3.20` | 8081 | **137 MB** | `4e0608ffefaf` | https://hub.docker.com/r/coste123/madeo07-php |
| app-ruby | Ruby 3.3.8 (p144) | `ruby:3.3-alpine3.20` | 8082 | **125 MB** | `d57918a72c53` | https://hub.docker.com/r/coste123/madeo07-ruby |
| app-dart | Dart 3.5.4 (AOT) | `dart:3.5.4` (builder) + `debian:bookworm-slim` (runtime) | 8083 | **166 MB** | `5f47e1581e3a` | https://hub.docker.com/r/coste123/madeo07-dart |

> Decisiones de diseño reflejadas en los Dockerfiles:
> - **Tag pinado** (nunca `latest`) para la base.
> - **Multi-stage** para Dart: la imagen final no contiene el SDK (~800 MB).
> - **Usuario no-root** (`USER app`) en las tres imágenes.
> - `EXPOSE`, `HEALTHCHECK` y `LABEL org.opencontainers.image.*` en las tres.
> - `.dockerignore` en cada carpeta para evitar incluir `.git`, `.DS_Store`, etc.

---

## 7. Problemas encontrados y resolución

| # | Problema | Causa | Solución |
|---|---|---|---|
| 1 | Primera idea: usar `alpine` también para el runtime de Dart. | El binario `dart compile exe` enlaza dinámicamente contra **glibc**; Alpine usa **musl** y falla con `Error loading shared library ld-linux-aarch64.so.1: No such file or directory`. | Runtime Dart cambiado a `debian:bookworm-slim`, documentado en `app-dart/README.md`. |
| 2 | `buildx --load` falla con `--platform linux/amd64,linux/arm64`. | Limitación conocida de BuildKit: `--load` solo exporta a la imagen local una plataforma a la vez. | Durante el desarrollo local se usa `--platform linux/arm64 --load`; en el push final se usa `--platform linux/amd64,linux/arm64 --push`. |
| 3 | WEBrick no está disponible en Ruby 3.3 por defecto. | Desde Ruby 3.0, WEBrick dejó la stdlib y pasó a ser una gema. | `RUN gem install webrick -v 1.8.1 --no-document` en el Dockerfile de Ruby. |
| 4 | Las fechas en las tres apps no estaban unificadas (PHP y Ruby mostraban hora local sin indicarlo; Dart mostraba ISO 8601 con sufijo `Z`). | Cada runtime genera la fecha con su API propia. | PHP → `gmdate('Y-m-d H:i:s')`. Ruby → `Time.now.utc.strftime(...)`. Dart → formateo manual del `DateTime.now().toUtc()`. Las tres muestran la misma etiqueta **"Fecha y hora del servidor (UTC)"**. |

---

## 8. Checklist final

- [x] Tres apps en lenguajes distintos: **PHP, Ruby, Dart** (sin Node/Python/Java/Go/C#/Rust/JVM).
- [x] Puertos distintos: **8081, 8082, 8083**.
- [x] HTML con nombre, lenguaje+versión, hostname y fecha UTC en `GET /` (formato unificado `YYYY-MM-DD HH:MM:SS`).
- [x] JSON `{"status":"ok","language":"…"}` en `GET /health`.
- [x] Imagen base con tag pinado en cada Dockerfile.
- [x] Multi-stage (Dart).
- [x] `USER` no-root en las tres.
- [x] `EXPOSE`, `HEALTHCHECK` y `LABEL org.opencontainers.image.*` en las tres.
- [x] `.dockerignore` en cada app.
- [x] Comentarios en español (con tildes) en todas las instrucciones del Dockerfile.
- [x] `run-all.sh` que reconstruye, levanta y verifica.
- [x] Imágenes etiquetadas como `coste123/madeo07-<lenguaje>:1.0.0` y `:latest`.
- [x] Build arm64 local verificado.
- [x] Sesión iniciada en Docker Hub vía Docker Desktop (Google SSO, keychain de macOS).
- [x] `docker buildx build --platform linux/amd64,linux/arm64 --push …` ejecutado para las tres apps.
- [x] `docker buildx imagetools inspect` confirma `linux/amd64` **y** `linux/arm64` en los seis tags publicados.
- [x] **Despliegue desde el registro verificado**: `docker rmi` → `docker pull` → `docker run` → `docker ps` muestra `coste123/madeo07-*:1.0.0` como imagen (no hash) y los tres contenedores `(healthy)`.

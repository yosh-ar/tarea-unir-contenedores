# EXPLICACIÓN — `nginx-golang-postgres` línea por línea

Este documento acompaña a [`EVIDENCIAS.md`](EVIDENCIAS.md) y a [`ORIGEN.md`](ORIGEN.md). Está dirigido a la rúbrica académica de la Actividad 1 — Parte 2 (Contenedores, Maestría en DevOps, UNIR), por lo que la lectura es minuciosa: se explica **cada línea** del `backend/Dockerfile` y del `compose.yaml` tal como vienen en `docker/awesome-compose`.

Los dos archivos no se tocaron salvo lo justificado en [`ORIGEN.md`](ORIGEN.md) (versiones con versión fija y remapeo de puerto). Las referencias a *la etapa X* o *la línea Y* son sobre el texto original.

---

## 1. `backend/Dockerfile`

El `Dockerfile` del backend declara **tres etapas** en un único archivo:

1. `builder` — compila el binario Go.
2. `dev-envs` — extiende la anterior con utilidades de desarrollo.
3. (anónima) `FROM scratch` — empaqueta solamente el binario para producción.

```dockerfile
# syntax=docker/dockerfile:1.4
```

Habilita el *frontend* moderno de BuildKit (versión 1.4). Es imprescindible porque el `Dockerfile` usa dos características que solo existen en ese frontend: los *cache mounts* `--mount=type=cache` y los *heredocs* `RUN <<EOF`.

### 1.1 Etapa `builder`

```dockerfile
FROM --platform=$BUILDPLATFORM golang:1.18-alpine AS builder
```

- `golang:1.18-alpine` es la imagen oficial de Go 1.18 sobre Alpine Linux. Trae el compilador, las herramientas y `apk`.
- `--platform=$BUILDPLATFORM` fuerza esta etapa a construirse en la **plataforma del constructor** (p. ej. `linux/arm64` en el Mac M-series) en lugar de la plataforma objetivo. Combinado con `CGO_ENABLED=0` más abajo, esto permite *cross-compilar* un binario para `linux/amd64` desde una máquina `linux/arm64` sin emulación QEMU durante la compilación. Es una de las técnicas estándar para builds multi-arquitectura eficientes.
- `AS builder` nombra la etapa; otras etapas la referencian con `--from=builder`.

```dockerfile
WORKDIR /code
```

Fija el directorio de trabajo. Todo `COPY` y `RUN` posterior opera dentro de `/code`.

```dockerfile
ENV CGO_ENABLED 0
ENV GOPATH /go
ENV GOCACHE /go-build
```

- `CGO_ENABLED=0` desactiva CGO. El binario resultante es **estático** y no depende de `libc`, lo que es condición indispensable para que la etapa final `FROM scratch` funcione (una imagen `scratch` no contiene ni siquiera `ld-linux`).
- `GOPATH=/go` y `GOCACHE=/go-build` fijan las rutas donde Go descarga módulos y almacena la caché de compilación. Se fijan explícitamente para que los *cache mounts* de abajo apunten a los directorios correctos.

```dockerfile
COPY go.mod go.sum ./
RUN --mount=type=cache,target=/go/pkg/mod/cache \
    go mod download
```

- Copia **solo** los manifiestos de módulos. Esto permite que la capa de resolución de dependencias se mantenga en caché mientras no cambie `go.mod`/`go.sum`.
- `--mount=type=cache,target=/go/pkg/mod/cache` es un *cache mount* de BuildKit: Docker monta un directorio efímero durante este `RUN` y lo persiste entre builds. Así, `go mod download` reutiliza los módulos descargados anteriormente aunque la capa Docker se invalide. No ocupa espacio en la imagen final (no es una capa).

```dockerfile
COPY . .

RUN --mount=type=cache,target=/go/pkg/mod/cache \
    --mount=type=cache,target=/go-build \
    go build -o bin/backend main.go
```

- Trae ahora el resto del código fuente (orden intencional: código después de dependencias, para preservar la caché).
- Dos *cache mounts* esta vez: el de módulos (igual que antes) y además `/go-build` para la caché de artefactos de compilación de Go. En reconstrucciones con cambios pequeños, solo se recompilan los paquetes afectados.
- `go build -o bin/backend main.go` produce el binario en `/code/bin/backend`.

```dockerfile
CMD ["/code/bin/backend"]
```

El `CMD` de la etapa `builder` sirve para los casos en que un `docker run` apunte directamente a la etapa `builder` (que es exactamente lo que ocurre en este proyecto con `target: builder`, ver §2.2).

### 1.2 Etapa `dev-envs`

```dockerfile
FROM builder as dev-envs

RUN <<EOF
apk update
apk add git
EOF

RUN <<EOF
addgroup -S docker
adduser -S --shell /bin/bash --ingroup docker vscode
EOF

# install Docker tools (cli, buildx, compose)
COPY --from=gloursdocker/docker / /

CMD ["go", "run", "main.go"]
```

- Esta etapa **extiende** `builder` para montar un entorno de desarrollo pensado para los *Docker Dev Environments* (soporte dentro de VS Code, Docker Desktop, etc.).
- `RUN <<EOF … EOF` es un **heredoc** de BuildKit: cada línea se ejecuta en el mismo `/bin/sh`. Es más legible que un `RUN a && b && c`.
- Crea un usuario `vscode` en el grupo `docker` para que la IDE pueda conectar sin privilegios de root.
- `COPY --from=gloursdocker/docker / /` arrastra el CLI de Docker, `buildx` y `compose` desde la imagen `gloursdocker/docker` para que el contenedor de desarrollo pueda, a su vez, hablar con el daemon de Docker del host.
- El `CMD` cambia a `go run main.go`: en desarrollo interesa el ciclo *edit-run* sin pasar por `go build` cada vez.

**Esta etapa no se usa en nuestra ejecución con Docker Compose.** Compose llama a `target: builder` (ver §2.1); la etapa `dev-envs` solo se activa si alguien lanza `docker build --target dev-envs ...` manualmente o desde la UI de Dev Environments.

### 1.3 Etapa final anónima — `FROM scratch`

```dockerfile
FROM scratch
COPY --from=builder /code/bin/backend /usr/local/bin/backend
CMD ["/usr/local/bin/backend"]
```

- `scratch` es la **imagen vacía** oficial de Docker: 0 bytes, 0 archivos, ni siquiera `/bin/sh`.
- Copia solamente el binario estático producido en la etapa `builder`. El resultado es una imagen minimalista: contiene **únicamente** el binario Go.
- `CMD` apunta al binario; al ser el PID 1 del contenedor, recibe directamente las señales (SIGTERM, SIGINT) y no hace falta `tini` ni ningún wrapper.

**Por qué `scratch`.** Esta es la razón por la que el `Dockerfile` desactiva CGO en §1.1 — sin dependencias nativas, el binario puede correr en `scratch`. Las ventajas:

- Superficie de ataque mínima (no hay utilidades aprovechables en caso de RCE).
- Tamaño de imagen pequeñísimo (unos pocos MB).
- Sin paquetes del sistema que mantener/parchear.

Como contrapartida: no se puede entrar al contenedor con `docker exec … sh`, no hay `curl` para `HEALTHCHECK` y no hay utilidades para depuración — por eso en producción algunos equipos prefieren `distroless/static` o `alpine`.

> **Nota operativa (importante para la rúbrica).** El `compose.yaml` del ejemplo establece `target: builder` en el bloque `build` del servicio `backend` (ver §2.1). Esto significa que **cuando ejecutamos `docker compose up -d --build`, la etapa `scratch` no interviene**: Compose detiene la construcción en la etapa `builder`, y el contenedor `backend` arranca a partir de `golang:1.18-alpine` con el binario adentro, no de `scratch`. La imagen final `scratch` queda disponible en el `Dockerfile` como opción de empaquetado para producción, pero este proyecto no la utiliza en el flujo documentado.

---

## 2. `compose.yaml`

```yaml
services:
  backend:
    build:
      context: backend
      target: builder
    secrets:
      - db-password
    depends_on:
      db:
        condition: service_healthy
```

### 2.1 Servicio `backend`

- `build.context: backend` — Compose construye la imagen a partir del `Dockerfile` dentro de la carpeta `backend/`.
- `build.target: builder` — detiene la construcción en la etapa `builder` (ver §1.3). La imagen final usada por el servicio es la etapa `builder`, no la de `scratch`.
- `secrets: - db-password` — monta en el contenedor el archivo del secreto `db-password` como `/run/secrets/db-password`. Es lo que lee `backend/main.go`:

  ```go
  bin, err := ioutil.ReadFile("/run/secrets/db-password")
  ```

- `depends_on.db.condition: service_healthy` — Compose solo arrancará este contenedor cuando el healthcheck del servicio `db` esté en estado `healthy`. Esta forma larga (`condition: ...`) exige un healthcheck declarado en el servicio dependido; sin ella, `depends_on` garantizaría solo el *start*, no la salud.

### 2.2 Servicio `db`

```yaml
  db:
    image: postgres:17-alpine        # original: postgres  → ver ORIGEN.md C1
    restart: always
    user: postgres
    secrets:
      - db-password
    volumes:
      - db-data:/var/lib/postgresql/data
    environment:
      - POSTGRES_DB=example
      - POSTGRES_PASSWORD_FILE=/run/secrets/db-password
    expose:
      - 5432
    healthcheck:
      test: [ "CMD", "pg_isready" ]
      interval: 10s
      timeout: 5s
      retries: 5
```

- `image: postgres:17-alpine` — en el original era `image: postgres`. Fijar una versión concreta fue necesario porque el tag sin versión resolvió a PostgreSQL 18, que rechaza el volumen montado en `/var/lib/postgresql/data` (ver [`EVIDENCIAS.md`](EVIDENCIAS.md) §2.1 para el error literal). Al margen de ese error puntual, dejar la imagen sin versión es también una mala práctica porque introduce variabilidad entre ejecuciones.
- `restart: always` — si el proceso muere, Docker lo relanza indefinidamente. Útil en producción; en desarrollo se discute con el equipo. Es independiente de `depends_on`.
- `user: postgres` — fija el usuario del proceso dentro del contenedor. Buena práctica: ningún proceso corre como root.
- `secrets: - db-password` — igual que en `backend`. El entrypoint de la imagen de Postgres lee `POSTGRES_PASSWORD_FILE` y aplica la contraseña al rol `postgres`.
- `volumes: - db-data:/var/lib/postgresql/data` — monta el **volumen con nombre** `db-data` (declarado al final del archivo) en la ruta donde Postgres guarda su cluster. Es el único mecanismo que da **persistencia**: sin esta línea, los datos vivirían dentro de la capa escribible del contenedor y se perderían con cada `docker compose down`.
- `environment` — define la base inicial (`POSTGRES_DB=example`) y de dónde leer la contraseña.
- `expose: - 5432` — **declara** el puerto en el que escucha PostgreSQL dentro de la red Docker, pero **no lo publica** al host. Solo los contenedores en la misma red interna pueden alcanzar `db:5432`. Esto es intencional: los puertos de base de datos no deben estar expuestos al host en despliegues normales.
- `healthcheck` — ejecuta `pg_isready` cada 10 s con timeout de 5 s. El servicio pasa a `healthy` tras la primera respuesta exitosa. Es lo que habilita el arranque de `backend` (sección 2.1).

### 2.3 Servicio `proxy`

```yaml
  proxy:
    image: nginx:1.27-alpine         # original: nginx    → ver ORIGEN.md C2
    volumes:
      - type: bind
        source: ./proxy/nginx.conf
        target: /etc/nginx/conf.d/default.conf
        read_only: true
    ports:
      - 8080:80                      # original: 80:80    → ver ORIGEN.md C3
    depends_on:
      - backend
```

- `image: nginx:1.27-alpine` — misma lógica de fijar una versión concreta (C2).
- `volumes` con `type: bind` + `read_only: true` — se monta el archivo `proxy/nginx.conf` del host sobre `/etc/nginx/conf.d/default.conf`. La diferencia respecto al volumen con nombre de `db` es grande:
  - *Bind mount*: liga una ruta concreta del host a una ruta del contenedor. Útil para inyectar configuración o para desarrollo (edición en caliente). Depende del sistema de archivos del host.
  - *Volumen con nombre*: lo gestiona Docker, vive en `/var/lib/docker/volumes/` y es la opción recomendada para datos persistentes porque desacopla el ciclo de vida del dato del contenedor.
  - `read_only: true` evita que el contenedor pueda escribir sobre el archivo de configuración (defensa en profundidad). Nginx solo necesita leerlo.
- `ports: - 8080:80` — publica el puerto 80 del contenedor en el puerto 8080 del host (en el original era `80:80`; se cambió por el conflicto con Laravel Herd — ver [`ORIGEN.md`](ORIGEN.md) C3). La diferencia con `expose` es crucial: `ports` **sí** abre el puerto al host; `expose` es solo una anotación interna.
- `depends_on: - backend` — forma corta, sin `condition`. Solo garantiza que el contenedor `backend` haya empezado a arrancar antes de que el `proxy` arranque. **No** espera a un healthcheck del backend (no hay healthcheck definido en `backend`).

### 2.4 Red por defecto y resolución DNS por nombre de servicio

```yaml
# (no hay bloque "networks:" explícito)
```

Al no declarar redes, Compose crea automáticamente una red *bridge* llamada `<proyecto>_default` (en este caso `nginx-golang-postgres_default`). Todos los servicios del archivo se adhieren a ella. Dentro de esa red, Docker expone un **resolver DNS integrado** que traduce los nombres de servicio del `compose.yaml` a las IPs de los contenedores.

Esto es lo que permite que el `nginx.conf` del proxy diga:

```nginx
proxy_pass http://backend:8000;
```

y que `backend/main.go` abra la conexión como:

```go
sql.Open("postgres", "postgres://postgres:...@db:5432/example?sslmode=disable")
```

Los nombres `backend` y `db` no son hostnames mágicos: son los nombres de los servicios declarados en `services:`. Compose los resuelve a la IP interna del contenedor correspondiente. Esto es también lo que hace que **no haga falta publicar** el puerto 5432 de Postgres: el acceso ocurre completamente por la red interna.

### 2.5 Volúmenes y secretos declarados

```yaml
volumes:
  db-data:

secrets:
  db-password:
    file: db/password.txt
```

- `volumes.db-data` — declaración vacía: Compose crea el volumen con el *driver* por defecto (`local`). El nombre real en Docker será `nginx-golang-postgres_db-data` (prefijado por el nombre del proyecto).
- `secrets.db-password` — origen *file*: Compose copia el contenido de `db/password.txt` como un secreto que luego se expone como `/run/secrets/db-password` dentro de los contenedores que lo listen. En *swarm* se usaría un *driver* real; en Compose *standalone* es un bind mount simulado, pero el patrón de API es el mismo.

---

## 3. Mejoras propuestas (no aplicadas)

Las siguientes mejoras no se aplicaron en el repositorio para no desviarse del enunciado (*ejecutar y documentar un ejemplo existente*). Se dejan registradas aquí como propuesta razonada.

### 3.1 Fijar versión de todas las imágenes y del `syntax`

Lo que ya se hizo con `postgres` y `nginx` debería extenderse a cualquier otra imagen que entre en el proyecto (p. ej. si se añade un `redis`). También conviene fijar el `# syntax=docker/dockerfile:1.4` a un patch concreto (`1.4.3`) para garantizar que BuildKit no cambie el comportamiento del frontend entre máquinas.

### 3.2 Usar la etapa final (`scratch`) también desde Compose

Actualmente `compose.yaml` tiene `target: builder`. La imagen que corre el backend es, por tanto, `golang:1.18-alpine` con el binario encima; el tamaño medido con `docker images` es **494 MB**:

```bash
$ docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}" | grep backend
nginx-golang-postgres-backend   latest   494MB
```

Si en el `compose.yaml` se quitara `target: builder` (dejando que la construcción llegue a la etapa anónima `FROM scratch`), la imagen final mediría **11,3 MB** — valor obtenido construyendo manualmente la etapa final con `docker build .` desde la misma carpeta `backend/`:

```bash
$ docker build --platform linux/arm64 -t probe-scratch:local backend/
$ docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}" | grep probe-scratch
probe-scratch                   local    11.3MB
```

Es decir, la imagen que correría en producción sería unas 44 veces más pequeña y, además, tendría las ventajas de seguridad descritas en §1.3. La razón de que el ejemplo deje `target: builder` es, probablemente, que pretende servir también como entorno de desarrollo en el que `go run` resulta útil.

### 3.3 Añadir `healthcheck` al servicio `backend`

Hoy, `proxy` depende de `backend` sin `condition: service_healthy`. Esto significa que el proxy puede empezar a enrutar peticiones antes de que el backend haya terminado su `Prepare db`. En el ejemplo esto es tolerable porque la primera petición llega varios segundos después, pero en condiciones reales conviene:

```yaml
backend:
  healthcheck:
    test: ["CMD", "wget", "-q", "--spider", "http://127.0.0.1:8000/"]
    interval: 10s
    timeout: 3s
    retries: 5

proxy:
  depends_on:
    backend:
      condition: service_healthy
```

El reto en este stack concreto es que la etapa `builder` no trae `wget`; habría que añadirlo o usar la etapa `scratch` con un healthcheck basado en el propio binario (p. ej. un flag `--healthcheck`). Es parte del motivo por el que el ejemplo original no lo incluye.

### 3.4 Idempotencia del `prepare()` del backend

Como se mostró en [`EVIDENCIAS.md`](EVIDENCIAS.md) §5.4, el backend hace `DROP TABLE IF EXISTS blog` en cada arranque, lo que destruye cualquier dato añadido a la tabla `blog` entre reinicios. Importante: esto **no** significa que el volumen falle — la prueba independiente de §5.6 (sobre una tabla `persistencia` que el backend no toca) demuestra que el volumen conserva los datos. El problema es puramente del código de la aplicación. En un proyecto real, la carga inicial de datos debería ser:

- Idempotente (p. ej. `CREATE TABLE IF NOT EXISTS` + `INSERT ... ON CONFLICT DO NOTHING`).
- Gestionada por una herramienta de migraciones (goose, flyway, etc.), no en línea con el arranque del servidor.

Esta mejora excede el alcance de la Parte 2 pero conviene señalarla porque explica por qué, en este ejemplo concreto, los datos añadidos a la tabla `blog` se pierden al reiniciar.

### 3.5 El archivo `db/password.txt` está versionado

El ejemplo trae el secreto de la base de datos (`db/password.txt`) committed en el repositorio para que funcione *out of the box*. Este fichero se expone a los contenedores como `/run/secrets/db-password` mediante el bloque `secrets:` del `compose.yaml` (ver §2.5).

En este trabajo se conserva tal cual **porque forma parte del material que se evalúa** (ejecutar y documentar el ejemplo original). En un entorno real nunca debería versionarse: lo apropiado es generar la contraseña fuera del repositorio y entregarla por un gestor de secretos externo. Opciones habituales:

- **Docker Swarm / Kubernetes secrets**: definir el secreto en el orquestador y montarlo con el mismo bloque `secrets:` de Compose.
- **Gestor dedicado**: HashiCorp Vault, AWS Secrets Manager, Google Secret Manager, 1Password, etc., inyectando el secreto en tiempo de despliegue.
- **Variables de entorno de la plataforma**: menos recomendable que las dos anteriores, pero mejor que committear el fichero.

En cualquiera de los tres casos, `db/password.txt` quedaría fuera del repositorio y entraría al `.gitignore`.

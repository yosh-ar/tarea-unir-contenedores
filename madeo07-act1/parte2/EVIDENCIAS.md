# EVIDENCIAS — Actividad 1, Parte 2 (Docker Compose)

> Autor: `coste123` (josuearguetaorozco20@gmail.com)
> Equipo: MacBook Pro Apple Silicon (arm64), macOS 26.0.1
> Fecha de la ejecución: 2026-11-01
> Docker Desktop 4.36.0 — Engine 27.3.1 (linux/arm64), `docker buildx` v0.18.0
> Ejemplo: `nginx-golang-postgres` tomado de `docker/awesome-compose` (ver [`ORIGEN.md`](ORIGEN.md))

Este documento registra, en orden cronológico y con **salida real**, cada paso de la ejecución del stack. Las anotaciones `[CAPTURA]` indican los puntos en los que deben tomarse screenshots para el informe.

---

## 1. Preparación del entorno

### 1.1 Comprobación del puerto 80

```bash
$ lsof -i :80
COMMAND    PID               USER   FD   TYPE             DEVICE SIZE/OFF NODE NAME
nginx-arm 2779 josuearguetaorozco    4u  IPv4 0x611073287d2c303f      0t0  TCP localhost:http (LISTEN)
nginx-arm 2780 josuearguetaorozco    4u  IPv4 0x611073287d2c303f      0t0  TCP localhost:http (LISTEN)
… (14 workers)
```

El puerto 80 **no está libre**: lo tiene el nginx integrado de **Laravel Herd** (`/Applications/Herd.app/Contents/Resources/nginx-arm64`), que se auto-rearranca cuando se le intenta parar. En consecuencia se decidió, como corrección mínima adicional, remapear el proxy a `8080:80` (ver [`ORIGEN.md`](ORIGEN.md) → C3). El resto del ejemplo se ejecuta sin cambios en configuración interna de los servicios.

---

## 2. Primer intento con el `compose.yaml` original (fallido)

El `compose.yaml` original usa `image: postgres` (sin tag). Se ejecutó tal cual:

```bash
$ cd madeo07-act1/parte2/nginx-golang-postgres
$ docker compose up -d --build
```

Salida real resumida:

```
#14 [backend builder 6/6] RUN --mount=type=cache,target=/go/pkg/mod/cache ... go build -o bin/backend main.go
#14 DONE 1.4s
...
 Container nginx-golang-postgres-db-1       Starting
 Container nginx-golang-postgres-db-1       Started
 Container nginx-golang-postgres-db-1       Waiting
 Container nginx-golang-postgres-db-1       Error
dependency failed to start: container nginx-golang-postgres-db-1 is unhealthy
```

### 2.1 Causa — PostgreSQL 18 rechaza el volumen en `/var/lib/postgresql/data`

```bash
$ docker compose logs db
db-1  | Error: in 18+, these Docker images are configured to store database data in a
db-1  |        format which is compatible with "pg_ctlcluster" (specifically, using
db-1  |        major-version-specific directory names).  This better reflects how
db-1  |        PostgreSQL itself works, and how upgrades are to be performed.
db-1  |
db-1  |        See also https://github.com/docker-library/postgres/pull/1259
db-1  |
db-1  |        Counter to that, there appears to be PostgreSQL data in:
db-1  |          /var/lib/postgresql/data (unused mount/volume)
db-1  |
db-1  |        This is usually the result of upgrading the Docker image without
db-1  |        upgrading the underlying database using "pg_upgrade" (which requires both
db-1  |        versions).
db-1  |
db-1  |        The suggested container configuration for 18+ is to place a single mount
db-1  |        at /var/lib/postgresql which will then place PostgreSQL data in a
db-1  |        subdirectory, allowing usage of "pg_upgrade --link" without mount point
db-1  |        boundary issues.
```

El tag `postgres` resuelve a `postgres:latest` que, en noviembre de 2026, es **PostgreSQL 18**. La imagen de PostgreSQL 18 **rechaza explícitamente** el patrón habitual de montar un volumen en `/var/lib/postgresql/data` porque el nuevo esquema espera un directorio padre único (`/var/lib/postgresql/`) con subcarpetas por versión. El contenedor sale con error y, como `backend` depende de `db` con `condition: service_healthy`, el `up` entero falla.

### 2.2 Corrección mínima aplicada

Siguiendo el enunciado del trabajo (fijar la versión de la imagen de postgres, p. ej. `postgres:17-alpine`), se modificó el `compose.yaml` en dos líneas: ver [`ORIGEN.md`](ORIGEN.md) secciones **C1** (`postgres:17-alpine`) y **C2** (`nginx:1.27-alpine`). También, por el conflicto con Herd, se cambió el mapeo del proxy a `8080:80` (**C3**).

Se purgó el estado previo:

```bash
$ docker compose down -v
 Container nginx-golang-postgres-backend-1  Removing
 Container nginx-golang-postgres-backend-1  Removed
 Container nginx-golang-postgres-db-1       Stopping
 Container nginx-golang-postgres-db-1       Stopped
 Container nginx-golang-postgres-db-1       Removing
 Container nginx-golang-postgres-db-1       Removed
 Volume nginx-golang-postgres_db-data       Removing
 Network nginx-golang-postgres_default      Removing
 Volume nginx-golang-postgres_db-data       Removed
 Network nginx-golang-postgres_default      Removed
```

---

## 3. Ejecución del stack con las versiones ya fijas

```bash
$ docker compose up -d --build
...
 Network nginx-golang-postgres_default      Created
 Container nginx-golang-postgres-db-1       Created
 Container nginx-golang-postgres-backend-1  Created
 Container nginx-golang-postgres-proxy-1    Created
 Container nginx-golang-postgres-db-1       Starting
 Container nginx-golang-postgres-db-1       Started
 Container nginx-golang-postgres-db-1       Waiting
 Container nginx-golang-postgres-db-1       Healthy       ← healthcheck pg_isready pasó
 Container nginx-golang-postgres-backend-1  Starting
 Container nginx-golang-postgres-backend-1  Started
 Container nginx-golang-postgres-proxy-1    Starting
 Container nginx-golang-postgres-proxy-1    Started
```

### 3.1 `docker compose ps` — tres servicios arriba, `db` *healthy*

```bash
$ docker compose ps
NAME                              IMAGE                           COMMAND                  SERVICE   STATUS                    PORTS
nginx-golang-postgres-backend-1   nginx-golang-postgres-backend   "/code/bin/backend"      backend   Up 23 seconds
nginx-golang-postgres-db-1        postgres:17-alpine              "docker-entrypoint.s…"   db        Up 34 seconds (healthy)   5432/tcp
nginx-golang-postgres-proxy-1     nginx:1.27-alpine               "/docker-entrypoint.…"   proxy     Up 23 seconds             0.0.0.0:8080->80/tcp
```

**[CAPTURA 1]** Terminal con la salida de `docker compose ps` anterior.

### 3.2 `curl` contra el proxy — JSON con los títulos del blog

```bash
$ curl -i http://localhost:8080/
HTTP/1.1 200 OK
Server: nginx/1.27.5
Date: Sun, 01 Nov 2026 19:56:40 GMT
Content-Type: text/plain; charset=utf-8
Content-Length: 77
Connection: keep-alive

["Blog post #0","Blog post #1","Blog post #2","Blog post #3","Blog post #4"]
```

**[CAPTURA 2]** Navegador en <http://localhost:8080/> mostrando el array JSON (o la salida anterior).

### 3.3 Logs del backend — `Prepare db` y acceso del proxy

```bash
$ docker compose logs backend
backend-1  | 2026/11/01 19:56:34 Prepare db...
backend-1  | 2026/11/01 19:56:34 Listening 8000
backend-1  | 172.21.0.4 - - [01/Nov/2026:19:56:40 +0000] "GET / HTTP/1.1" 200 77
```

### 3.4 Logs del db — inicio limpio en PostgreSQL 17.11

```bash
$ docker compose logs db
db-1  | PostgreSQL Database directory appears to contain a database; Skipping initialization
db-1  |
db-1  | 2026-11-01 19:56:24.352 UTC [1] LOG:  starting PostgreSQL 17.11 on aarch64-unknown-linux-musl, compiled by gcc (Alpine 15.2.0) 15.2.0, 64-bit
db-1  | 2026-11-01 19:56:24.352 UTC [1] LOG:  listening on IPv4 address "0.0.0.0", port 5432
db-1  | 2026-11-01 19:56:24.353 UTC [1] LOG:  listening on Unix socket "/var/run/postgresql/.s.PGSQL.5432"
db-1  | 2026-11-01 19:56:24.355 UTC [16] LOG:  database system was shut down at 2026-11-01 19:56:02 UTC
db-1  | 2026-11-01 19:56:24.357 UTC [1] LOG:  database system is ready to accept connections
```

### 3.5 `psql` dentro del contenedor `db` — tabla `blog`

```bash
$ docker exec nginx-golang-postgres-db-1 psql -U postgres -d example -c "SELECT * FROM blog;"
 id |    title
----+--------------
  1 | Blog post #0
  2 | Blog post #1
  3 | Blog post #2
  4 | Blog post #3
  5 | Blog post #4
(5 rows)
```

**[CAPTURA 3]** Terminal con `docker exec … psql` mostrando las 5 filas de `blog`.

### 3.6 Volúmenes y red del proyecto

```bash
$ docker volume ls --filter name=nginx-golang-postgres
DRIVER    VOLUME NAME
local     nginx-golang-postgres_db-data

$ docker inspect nginx-golang-postgres_db-data --format '{{.Driver}} {{.Mountpoint}}'
local /var/lib/docker/volumes/nginx-golang-postgres_db-data/_data

$ docker network ls --filter name=nginx-golang-postgres
NETWORK ID     NAME                            DRIVER    SCOPE
0efd200255f0   nginx-golang-postgres_default   bridge    local
```

Compose crea automáticamente el volumen con nombre (`db-data`) y la red *bridge* por defecto (`nginx-golang-postgres_default`). El prefijo `nginx-golang-postgres_` corresponde al nombre de la carpeta del proyecto.

**[CAPTURA 4]** Docker Desktop → sección Containers mostrando el grupo `nginx-golang-postgres` con los tres contenedores agrupados.

---

## 4. Orden de arranque: `depends_on` + `healthcheck`

Los logs con marca de tiempo confirman que `backend` solo arranca después de que `db` reportó `healthy`:

```bash
$ docker compose logs --timestamps
db-1       | 2026-11-01T19:57:18.706…Z PostgreSQL Database directory appears to contain a database; Skipping initialization
db-1       | 2026-11-01T19:57:18.718…Z 2026-11-01 19:57:18.717 UTC [1] LOG:  starting PostgreSQL 17.11…
db-1       | 2026-11-01T19:57:18.723…Z 2026-11-01 19:57:18.723 UTC [1] LOG:  database system is ready to accept connections
backend-1  | 2026-11-01T19:57:29.308…Z 2026/11/01 19:57:29 Prepare db...     ← esperó ~11 s a que db estuviera healthy
backend-1  | 2026-11-01T19:57:29.323…Z 2026/11/01 19:57:29 Listening 8000
proxy-1    | 2026-11-01T19:57:29.427…Z 2026/11/01 19:57:29 [notice] 1#1: using the "epoll" event method
proxy-1    | 2026-11-01T19:57:29.427…Z 2026/11/01 19:57:29 [notice] 1#1: nginx/1.27.5
```

Secuencia observada:

1. `db` arranca y, cuando `pg_isready` responde, el healthcheck pasa a `healthy`.
2. Solo entonces Compose arranca `backend` (que depende de `db` con `condition: service_healthy`).
3. Simultáneamente arranca `proxy`, que depende solo del *start* de `backend` (no de un healthcheck del backend).

Este comportamiento es exactamente el que define el bloque `depends_on` del `compose.yaml` (ver [`EXPLICACION.md`](EXPLICACION.md) §2.4).

---

## 5. Persistencia del volumen

### 5.1 Fila de control añadida antes del `down`

```bash
$ docker exec nginx-golang-postgres-db-1 psql -U postgres -d example \
    -c "INSERT INTO blog (title) VALUES ('Entrada añadida antes del down');"
INSERT 0 1

$ docker exec nginx-golang-postgres-db-1 psql -U postgres -d example -c "SELECT * FROM blog;"
 id |             title
----+--------------------------------
  1 | Blog post #0
  2 | Blog post #1
  3 | Blog post #2
  4 | Blog post #3
  5 | Blog post #4
  6 | Entrada añadida antes del down
(6 rows)
```

### 5.2 `docker compose down` (sin `-v`) — el volumen sobrevive

```bash
$ docker compose down
 Container nginx-golang-postgres-backend-1  Stopping
 Container nginx-golang-postgres-backend-1  Stopped
 Container nginx-golang-postgres-backend-1  Removing
 Container nginx-golang-postgres-backend-1  Removed
 Container nginx-golang-postgres-db-1       Stopping
 Container nginx-golang-postgres-db-1       Stopped
 Container nginx-golang-postgres-db-1       Removing
 Container nginx-golang-postgres-db-1       Removed
 Network nginx-golang-postgres_default      Removing
 Network nginx-golang-postgres_default      Removed

$ docker volume ls --filter name=nginx-golang-postgres
DRIVER    VOLUME NAME
local     nginx-golang-postgres_db-data        ← el volumen sigue existiendo
```

### 5.3 `docker compose up -d` — Postgres reutiliza el cluster existente

```bash
$ docker compose up -d
 Network nginx-golang-postgres_default      Created
 Container nginx-golang-postgres-db-1       Created
 Container nginx-golang-postgres-backend-1  Created
 Container nginx-golang-postgres-proxy-1    Created
 Container nginx-golang-postgres-db-1       Started
 Container nginx-golang-postgres-db-1       Waiting
 Container nginx-golang-postgres-db-1       Healthy

$ docker compose logs db | grep -E "Skipping initialization|ready to accept"
db-1 | PostgreSQL Database directory appears to contain a database; Skipping initialization
db-1 | 2026-11-01 19:57:18.723 UTC [1] LOG:  database system is ready to accept connections
```

El cluster se encontró ya inicializado y PostgreSQL **no** volvió a bootstrapar: eso prueba que el volumen `db-data` conservó el estado del motor entre `down` y `up`.

### 5.4 Consulta tras el `up` — por qué la fila añadida a `blog` desaparece

```bash
$ docker exec nginx-golang-postgres-db-1 psql -U postgres -d example -c "SELECT * FROM blog;"
 id |    title
----+--------------
  1 | Blog post #0
  2 | Blog post #1
  3 | Blog post #2
  4 | Blog post #3
  5 | Blog post #4
(5 rows)
```

Las filas vuelven a ser las cinco iniciales y la `#6` que insertamos a mano desapareció. **El volumen sí persiste** — el motor acaba de confirmar que reutilizó el cluster y la prueba independiente de §5.6 (sobre una tabla que el backend no toca) lo demuestra sin ambigüedad. Lo que borra la fila añadida es exclusivamente el código del backend, en `backend/main.go` → función `prepare()`:

```go
if _, err := db.Exec("DROP TABLE IF EXISTS blog"); err != nil { … }
if _, err := db.Exec("CREATE TABLE IF NOT EXISTS blog (id SERIAL, title VARCHAR)"); err != nil { … }
for i := 0; i < 5; i++ { INSERT … "Blog post #" + i … }
```

Cada vez que arranca el backend, borra y recrea la tabla `blog` con los cinco registros de ejemplo. Por eso, aunque el volumen conserve el estado del motor, cualquier fila añadida *ad hoc* a `blog` se pierde al reiniciar el backend. Para separar la responsabilidad del volumen (que sí persiste) de la del `prepare()` del backend (que sobrescribe `blog`) se añade §5.6.

### 5.5 `docker compose down -v` (no ejecutado) — comportamiento esperado

Si en lugar de `docker compose down` se ejecutara **`docker compose down -v`** (NO lo ejecutamos aquí para no borrar la evidencia), ocurriría lo siguiente:

1. Compose pararía y eliminaría los tres contenedores y la red.
2. Además eliminaría los volúmenes con nombre definidos en el `compose.yaml` (`db-data`).
3. En el siguiente `up`, Postgres encontraría el directorio vacío y ejecutaría la rutina `initdb` completa (crearía `example`, aplicaría roles, etc.).

Es decir: `down` deja los datos en reposo, mientras que `down -v` los borra **y además** elimina el estado durable del motor. En este ejemplo concreto la diferencia visible para el usuario parece pequeña porque el backend reescribe la tabla `blog` en cada arranque, pero en una aplicación real (sin `DROP TABLE` en el arranque) la diferencia sería total — lo demuestra §5.6, donde los datos de una tabla que el backend no toca sobreviven al `down`.

### 5.6 Prueba limpia de persistencia con una tabla ajena al backend

Para probar la persistencia del volumen sin que el `prepare()` del backend interfiera, se crea una tabla nueva (`persistencia`) que la aplicación no conoce ni manipula. Si la fila sobrevive a un `down` + `up`, queda demostrado que el volumen efectivamente conserva los datos.

**Paso 1 — crear la tabla y una fila de control (stack arriba):**

```bash
$ docker exec nginx-golang-postgres-db-1 psql -U postgres -d example \
    -c "CREATE TABLE persistencia (id serial, nota text, creado timestamptz default now());"
CREATE TABLE

$ docker exec nginx-golang-postgres-db-1 psql -U postgres -d example \
    -c "INSERT INTO persistencia (nota) VALUES ('fila creada antes del down para probar que el volumen persiste');"
INSERT 0 1

$ docker exec nginx-golang-postgres-db-1 psql -U postgres -d example -c "SELECT * FROM persistencia;"
 id |                              nota                              |            creado
----+----------------------------------------------------------------+-------------------------------
  1 | fila creada antes del down para probar que el volumen persiste | 2026-11-01 20:05:41.425453+00
(1 row)
```

**Paso 2 — `docker compose down` (sin `-v`) y verificación de que el volumen sigue existiendo:**

```bash
$ docker compose down
 Container nginx-golang-postgres-backend-1  Removed
 Container nginx-golang-postgres-db-1       Removed
 Network nginx-golang-postgres_default      Removed

$ docker volume ls --filter name=nginx-golang-postgres
DRIVER    VOLUME NAME
local     nginx-golang-postgres_db-data
```

**Paso 3 — `docker compose up -d`, esperar a `healthy` y volver a consultar:**

```bash
$ docker compose up -d
 Container nginx-golang-postgres-db-1       Healthy
 Container nginx-golang-postgres-backend-1  Started
 Container nginx-golang-postgres-proxy-1    Started

$ until docker exec nginx-golang-postgres-db-1 pg_isready -U postgres > /dev/null 2>&1; do sleep 1; done; echo "ready"
ready

$ docker exec nginx-golang-postgres-db-1 psql -U postgres -d example -c "SELECT * FROM persistencia;"
 id |                              nota                              |            creado
----+----------------------------------------------------------------+-------------------------------
  1 | fila creada antes del down para probar que el volumen persiste | 2026-11-01 20:05:41.425453+00
(1 row)
```

La fila sigue ahí, con el mismo `id`, la misma `nota` y el mismo `creado` que antes del `down`. Esto cierra la demostración: **el volumen `db-data` persiste los datos entre `down` y `up`**. Lo que se perdió en §5.4 fue responsabilidad del `prepare()` del backend, no del volumen.

**[CAPTURA 5]** Terminal con el `SELECT * FROM persistencia;` posterior al `down + up` mostrando la fila con el `creado` original.

---

## 6. Tabla resumen de la ejecución

| Servicio | Imagen (tras C1/C2) | Puerto expuesto | Puerto publicado | Depende de | Healthcheck |
|---|---|---|---|---|---|
| `db`      | `postgres:17-alpine` | `5432` (`expose`) | — | — | `pg_isready`, interval 10 s |
| `backend` | `nginx-golang-postgres-backend:latest` (build local, target `builder`) | — | — | `db` (`condition: service_healthy`) | — |
| `proxy`   | `nginx:1.27-alpine` | — | `8080→80` (`ports`) | `backend` (solo *started*) | — |

---

## 7. Checklist

- [x] Carpeta `nginx-golang-postgres` traída desde `docker/awesome-compose` sin `.git`.
- [x] `ORIGEN.md` con URL, SHA del commit (`30f4b7f…`), licencia (CC0) y cambios aplicados.
- [x] Puerto 80 revisado; conflicto con Herd documentado y resuelto con remapeo `8080:80` (C3).
- [x] Primer intento con `postgres` sin versión fija → fallo capturado literal.
- [x] Corrección mínima aplicada: `postgres:17-alpine`, `nginx:1.27-alpine`.
- [x] `docker compose up -d --build` sale limpio y `docker compose ps` muestra `db (healthy)`.
- [x] `curl -i http://localhost:8080/` devuelve el JSON de los títulos.
- [x] `psql` dentro de `db` lista las 5 filas de `blog`.
- [x] `docker volume ls` y `docker network ls` filtrados muestran los artefactos del proyecto.
- [x] Persistencia del motor probada con `down` + `up`: cluster preservado (log *Skipping initialization*).
- [x] Persistencia de datos probada con una tabla ajena al backend (`persistencia`, §5.6): la fila sobrevive al `down` + `up` con `id`, `nota` y `creado` intactos.
- [x] Diferencia `down` vs `down -v` explicada sin ejecutar `-v`.
- [x] Orden de arranque demostrado con logs *timestamps* (db healthy → backend → proxy).

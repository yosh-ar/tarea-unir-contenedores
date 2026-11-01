# ORIGEN del ejemplo nginx-golang-postgres

Esta carpeta contiene **únicamente** el ejemplo `nginx-golang-postgres` del repositorio oficial `docker/awesome-compose`. No se escribió código de aplicación: la Actividad 1 — Parte 2 exige ejecutar y documentar un ejemplo preexistente.

## Trazabilidad del origen

| Campo | Valor |
|---|---|
| Repositorio | <https://github.com/docker/awesome-compose> |
| Rama / referencia | `master` (HEAD en el momento de la clonación) |
| Commit (SHA) | `30f4b7f6a6c3b0c0ecf4d4efb0de203c48d11562` |
| Fecha del commit | 2026-06-15 |
| Carpeta copiada | `nginx-golang-postgres/` |
| Fecha de la clonación | 2026-11-01 |
| Licencia del repositorio | **CC0 1.0 Universal** (Dominio público; archivo `LICENSE` en la raíz del repo original) |

Comando usado para traerlo:

```bash
git clone --depth=1 https://github.com/docker/awesome-compose.git /tmp/awesome-compose-clone
cp -R /tmp/awesome-compose-clone/nginx-golang-postgres \
      madeo07-act1/parte2/nginx-golang-postgres
```

> **Nota:** se copió exclusivamente la carpeta `nginx-golang-postgres/`. El directorio `.git/` del repositorio origen **no** forma parte de este repo (se verificó que no se arrastró ningún `.git` interno).

## Cambios aplicados respecto al original

Las correcciones aquí registradas son las **mínimas** necesarias para que `docker compose up -d --build` funcione en el entorno de evaluación (Docker Desktop 4.36.0, Engine 27.3.1, macOS arm64, noviembre de 2026). Cualquier cambio adicional queda pendiente para una futura iteración y está anotado en `EXPLICACION.md` → sección *Mejoras propuestas*.

### C1 — Fijar versión de `postgres`

- **Archivo:** `compose.yaml`
- **Antes:** `image: postgres`
- **Después:** `image: postgres:17-alpine`
- **Motivo:** sin versión, el tag `postgres` resolvió a `postgres:latest`, que en el entorno de evaluación corresponde a **PostgreSQL 18**. Esa imagen rechaza el volumen montado en `/var/lib/postgresql/data` con el error literal registrado en [`EVIDENCIAS.md`](EVIDENCIAS.md) §2.1:

  > `Error: in 18+, these Docker images are configured to store database data in a format which is compatible with "pg_ctlcluster" (specifically, using major-version-specific directory names). […] Counter to that, there appears to be PostgreSQL data in: /var/lib/postgresql/data (unused mount/volume)`

  Fijar `postgres:17-alpine` elimina el conflicto y mantiene el patrón de montaje definido por el ejemplo.

### C2 — Fijar versión de `nginx`

- **Archivo:** `compose.yaml`
- **Antes:** `image: nginx`
- **Después:** `image: nginx:1.27-alpine`
- **Motivo:** fijar una versión concreta (en vez de depender implícitamente de `latest`) para que la imagen usada no cambie entre ejecuciones.

### C3 — Mapeo de puerto del proxy a `8080:80`

- **Archivo:** `compose.yaml`
- **Antes:** `ports: - 80:80`
- **Después:** `ports: - 8080:80`
- **Motivo:** en la máquina de evaluación, el puerto 80 del host está ocupado por el nginx que trae **Laravel Herd** (servicio local de desarrollo PHP que se autorrearranca). Cambiar el mapeo a `8080:80` es la alteración mínima que permite ejecutar el ejemplo sin modificar la configuración del equipo del usuario. La configuración interna del proxy (`nginx.conf` escucha en el puerto 80 del contenedor) y la red `nginx-golang-postgres_default` no cambian. La aplicación responde ahora en `http://localhost:8080/` en vez de `http://localhost/`.

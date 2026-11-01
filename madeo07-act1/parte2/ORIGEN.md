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

<!-- Esta sección se completa durante la ejecución del paso 2 (ver EVIDENCIAS.md). -->

### C1 — Fijar versión de `postgres`

- **Archivo:** `compose.yaml`
- **Antes:** `image: postgres`
- **Después:** `image: postgres:17-alpine`
- **Motivo:** el tag `postgres` sin versión resuelve a `postgres:latest`, que en noviembre de 2026 corresponde a **PostgreSQL 18**. El `main.go` del ejemplo fue probado contra PostgreSQL 13–15 y, además, dejar la versión implícita rompe la reproducibilidad del build (requisito explícito de la asignatura). Fijar `17-alpine` resuelve ambos problemas con el menor cambio posible.

### C2 — Fijar versión de `nginx`

- **Archivo:** `compose.yaml`
- **Antes:** `image: nginx`
- **Después:** `image: nginx:1.27-alpine`
- **Motivo:** mismo principio que C1 — el ejemplo no debería depender del `latest` del día. Se fija a la rama estable `1.27` sobre Alpine para mantener la imagen pequeña y la configuración `nginx.conf` compatible.

### C3 — Mapeo de puerto del proxy a `8080:80`

- **Archivo:** `compose.yaml`
- **Antes:** `ports: - 80:80`
- **Después:** `ports: - 8080:80`
- **Motivo:** en la máquina de evaluación, el puerto 80 del host está ocupado por el nginx que trae **Laravel Herd** (servicio local de desarrollo PHP que se autorrearranca). Cambiar el mapeo a `8080:80` es la alteración mínima que permite ejecutar el ejemplo sin modificar la configuración del equipo del usuario. La configuración interna del proxy (`nginx.conf` escucha en el puerto 80 del contenedor) y el `nginx-golang-postgres_default` network no cambian. La aplicación responde ahora en `http://localhost:8080/` en vez de `http://localhost/`.

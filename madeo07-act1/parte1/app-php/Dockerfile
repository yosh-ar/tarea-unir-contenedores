# =========================================================================
# app-php : microservicio HTTP (PHP) para la Actividad 1 de Contenedores
# =========================================================================

# Imagen base oficial con tag pinado (PHP 8.3 CLI sobre Alpine 3.20).
# Pinamos tanto la rama de PHP como la de Alpine para builds reproducibles
# y evitar las sorpresas del tag :latest.
FROM php:8.3-cli-alpine3.20

# Metadatos OCI estándar: permiten inspeccionar la imagen (docker inspect)
# y aparecen en registries. Documentan autor, origen y versión.
LABEL org.opencontainers.image.title="madeo07-php" \
      org.opencontainers.image.description="Microservicio HTTP en PHP para la Actividad 1 de Contenedores (UNIR)" \
      org.opencontainers.image.source="https://hub.docker.com/r/coste123/madeo07-php" \
      org.opencontainers.image.version="1.0.0" \
      org.opencontainers.image.authors="coste123 <josuearguetaorozco20@gmail.com>" \
      org.opencontainers.image.licenses="MIT"

# Directorio de trabajo dentro de la imagen; aquí vivirá el código.
WORKDIR /app

# Copiamos solo el front-controller: cambios en el código invalidan solo
# esta capa, maximizando el aprovechamiento de la caché de build.
COPY index.php /app/index.php

# Creamos un usuario de sistema sin shell y sin privilegios y le damos
# posesión de /app. Correr procesos como root dentro del contenedor es
# una mala práctica de seguridad (CIS Docker Benchmark 4.1).
RUN addgroup -S app && adduser -S -G app -s /sbin/nologin app \
    && chown -R app:app /app

# Declaramos el puerto en el que escucha el proceso (documentación y
# compatibilidad con -P). El puerto efectivo se publica con -p al correr.
EXPOSE 8081

# Healthcheck integrado: wget viene en busybox de Alpine y basta para
# confirmar que /health responde HTTP 200.
HEALTHCHECK --interval=15s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -q --spider http://127.0.0.1:8081/health || exit 1

# A partir de aquí el proceso corre sin privilegios de root.
USER app

# Lanzamos el servidor web embebido de PHP (incluido con el runtime CLI).
# -S fija host:puerto; -t fija el docroot; el último argumento es el
# router (front-controller) que atiende todas las peticiones.
CMD ["php", "-S", "0.0.0.0:8081", "-t", "/app", "/app/index.php"]

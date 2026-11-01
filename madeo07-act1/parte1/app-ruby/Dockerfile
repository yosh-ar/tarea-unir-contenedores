# =========================================================================
# app-ruby : microservicio HTTP (Ruby + WEBrick) para la Actividad 1
# =========================================================================

# Imagen base oficial con tag pinado (Ruby 3.3 sobre Alpine 3.20). Pinar
# ambas versiones hace que el build sea reproducible, y evita el riesgo
# de un salto de versión con :latest.
FROM ruby:3.3-alpine3.20

# Metadatos OCI estándar (visibles con docker inspect).
LABEL org.opencontainers.image.title="madeo07-ruby" \
      org.opencontainers.image.description="Microservicio HTTP en Ruby (WEBrick) para la Actividad 1 de Contenedores (UNIR)" \
      org.opencontainers.image.source="https://hub.docker.com/r/coste123/madeo07-ruby" \
      org.opencontainers.image.version="1.0.0" \
      org.opencontainers.image.authors="coste123 <josuearguetaorozco20@gmail.com>" \
      org.opencontainers.image.licenses="MIT"

# Directorio de trabajo para el código de la aplicación.
WORKDIR /app

# WEBrick se separó de la stdlib de Ruby desde la versión 3.0, por lo
# que debemos instalarlo como gema. --no-document ahorra espacio al
# omitir rdoc/ri y pinamos la versión por reproducibilidad.
RUN gem install webrick -v 1.8.1 --no-document

# Copiamos el único archivo fuente. Mantenerlo en una capa separada
# aprovecha mejor la caché cuando solo cambia el código.
COPY server.rb /app/server.rb

# Usuario de sistema sin shell, propietario de /app. Evita correr
# como root dentro del contenedor (buena práctica de seguridad).
RUN addgroup -S app && adduser -S -G app -s /sbin/nologin app \
    && chown -R app:app /app

# Puerto declarado para documentación y para -P.
EXPOSE 8082

# Healthcheck con wget (incluido en busybox/alpine).
HEALTHCHECK --interval=15s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -q --spider http://127.0.0.1:8082/health || exit 1

# A partir de aquí el proceso ya no corre como root.
USER app

# Arrancamos el servidor WEBrick ejecutando el script directamente.
CMD ["ruby", "/app/server.rb"]

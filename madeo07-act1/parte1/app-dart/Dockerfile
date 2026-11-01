# =========================================================================
# app-dart : microservicio HTTP (Dart compilado AOT) para la Actividad 1
# -------------------------------------------------------------------------
# Dart admite compilación AOT a un binario nativo. Usamos un multi-stage
# para que la imagen final no incluya el SDK (~800 MB) sino solo el
# ejecutable, reduciendo drásticamente el tamaño y la superficie de ataque.
# =========================================================================

# -------------------------------------------------------------------------
# Etapa 1 - builder: contiene el SDK completo de Dart.
# -------------------------------------------------------------------------
# Tag pinado al patch 3.5.4 para builds reproducibles.
FROM dart:3.5.4 AS builder

# Directorio de trabajo para el código fuente.
WORKDIR /src

# Copiamos primero el manifiesto. Si pubspec.yaml no cambia, 'dart pub get'
# se sirve de la caché en re-builds (aunque no haya dependencias externas,
# mantener el patrón es útil cuando se agreguen).
COPY pubspec.yaml ./
RUN dart pub get

# Copiamos el resto del código fuente.
COPY bin ./bin

# Compilación AOT a ejecutable nativo. El binario resultante incluye el
# runtime de Dart y solo depende de la libc del sistema.
RUN dart compile exe bin/server.dart -o /src/server

# -------------------------------------------------------------------------
# Etapa 2 - runtime: imagen mínima con solo el binario y lo imprescindible.
# -------------------------------------------------------------------------
# Debian slim comparte glibc con la imagen de builder (dart oficial), por
# lo que el binario compilado funciona sin recompilar. Alpine (musl) no
# serviría aquí.
FROM debian:bookworm-slim

# Metadatos OCI estándar.
LABEL org.opencontainers.image.title="madeo07-dart" \
      org.opencontainers.image.description="Microservicio HTTP en Dart (compilado AOT) para la Actividad 1 de Contenedores (UNIR)" \
      org.opencontainers.image.source="https://hub.docker.com/r/coste123/madeo07-dart" \
      org.opencontainers.image.version="1.0.0" \
      org.opencontainers.image.authors="coste123 <josuearguetaorozco20@gmail.com>" \
      org.opencontainers.image.licenses="MIT"

# Dependencias de runtime estrictas: wget para el healthcheck y
# ca-certificates por si la app realiza llamadas HTTPS salientes.
# Limpiamos los listados de apt y la caché para no inflar la imagen.
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates wget \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Directorio donde vivirá el binario.
WORKDIR /app

# Copiamos el binario desde la etapa builder; esto deja fuera el SDK.
COPY --from=builder /src/server /app/server

# Usuario de sistema sin shell y sin privilegios, propietario del binario.
RUN chmod +x /app/server \
    && groupadd -r app \
    && useradd -r -g app -s /usr/sbin/nologin app \
    && chown -R app:app /app

# Puerto declarado para documentación.
EXPOSE 8083

# Healthcheck con wget contra /health.
HEALTHCHECK --interval=15s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -q --spider http://127.0.0.1:8083/health || exit 1

# Dejamos de ser root para ejecutar el proceso.
USER app

# El binario AOT es el PID 1 del contenedor; recibe señales directamente.
CMD ["/app/server"]

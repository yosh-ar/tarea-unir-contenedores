import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> args) async {
  final port = int.parse(Platform.environment['PORT'] ?? '8083');
  final server = await HttpServer.bind(InternetAddress.anyIPv4, port);
  stdout.writeln('app-dart listening on 0.0.0.0:$port');

  ProcessSignal.sigint.watch().listen((_) async {
    await server.close(force: true);
    exit(0);
  });
  ProcessSignal.sigterm.watch().listen((_) async {
    await server.close(force: true);
    exit(0);
  });

  await for (final req in server) {
    try {
      final path = req.uri.path;
      if (path == '/health') {
        final body = jsonEncode({'status': 'ok', 'language': 'dart'});
        req.response
          ..statusCode = 200
          ..headers.contentType =
              ContentType('application', 'json', charset: 'utf-8')
          ..write(body);
      } else if (path == '/') {
        final hostname = Platform.localHostname;
        final dartVersion = Platform.version.split(' ').first;
        final nowUtc = DateTime.now().toUtc();
        String two(int v) => v.toString().padLeft(2, '0');
        final now =
            '${nowUtc.year}-${two(nowUtc.month)}-${two(nowUtc.day)} '
            '${two(nowUtc.hour)}:${two(nowUtc.minute)}:${two(nowUtc.second)}';
        final html = '''<!doctype html>
<html lang="es">
<head><meta charset="utf-8"><title>app-dart - Actividad 1 UNIR</title>
<style>body{font-family:system-ui,sans-serif;max-width:640px;margin:3rem auto;padding:0 1rem}h1{color:#00B4AB}ul{line-height:1.8}code{background:#eee;padding:.1rem .3rem;border-radius:3px}</style>
</head>
<body>
  <h1>app-dart</h1>
  <p>Microservicio de demostración para la Actividad 1 de Contenedores (Maestría DevOps - UNIR).</p>
  <ul>
    <li><strong>Lenguaje:</strong> <code>Dart $dartVersion</code></li>
    <li><strong>Hostname del contenedor:</strong> <code>$hostname</code></li>
    <li><strong>Fecha y hora del servidor (UTC):</strong> <code>$now</code></li>
    <li><strong>Health:</strong> <a href="/health">/health</a></li>
  </ul>
</body>
</html>''';
        req.response
          ..statusCode = 200
          ..headers.contentType =
              ContentType('text', 'html', charset: 'utf-8')
          ..write(html);
      } else {
        req.response
          ..statusCode = 404
          ..headers.contentType =
              ContentType('text', 'plain', charset: 'utf-8')
          ..write('not found\n');
      }
    } catch (e) {
      req.response.statusCode = 500;
    } finally {
      await req.response.close();
    }
  }
}

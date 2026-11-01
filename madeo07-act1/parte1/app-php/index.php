<?php
// Front-controller único: la ruta solicitada decide la respuesta.
$uri = parse_url($_SERVER['REQUEST_URI'] ?? '/', PHP_URL_PATH);
$lang_version = 'PHP ' . PHP_VERSION;
$hostname = gethostname() ?: 'unknown';
$now = gmdate('Y-m-d H:i:s');

if ($uri === '/health') {
    header('Content-Type: application/json; charset=utf-8');
    echo json_encode(['status' => 'ok', 'language' => 'php']);
    return true;
}

if ($uri === '/' || $uri === '') {
    header('Content-Type: text/html; charset=utf-8');
    $html = <<<HTML
<!doctype html>
<html lang="es">
<head><meta charset="utf-8"><title>app-php - Actividad 1 UNIR</title>
<style>body{font-family:system-ui,sans-serif;max-width:640px;margin:3rem auto;padding:0 1rem}h1{color:#4F5D95}ul{line-height:1.8}code{background:#eee;padding:.1rem .3rem;border-radius:3px}</style>
</head>
<body>
  <h1>app-php</h1>
  <p>Microservicio de demostración para la Actividad 1 de Contenedores (Maestría DevOps - UNIR).</p>
  <ul>
    <li><strong>Lenguaje:</strong> <code>HTMLLANG</code></li>
    <li><strong>Hostname del contenedor:</strong> <code>HTMLHOST</code></li>
    <li><strong>Fecha y hora del servidor (UTC):</strong> <code>HTMLNOW</code></li>
    <li><strong>Health:</strong> <a href="/health">/health</a></li>
  </ul>
</body>
</html>
HTML;
    $html = str_replace(['HTMLLANG','HTMLHOST','HTMLNOW'],
        [htmlspecialchars($lang_version), htmlspecialchars($hostname), htmlspecialchars($now)], $html);
    echo $html;
    return true;
}

http_response_code(404);
header('Content-Type: text/plain; charset=utf-8');
echo "not found\n";
return true;

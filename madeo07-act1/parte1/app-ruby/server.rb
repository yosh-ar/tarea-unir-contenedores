#!/usr/bin/env ruby
# frozen_string_literal: true

# Servidor HTTP mínimo usando WEBrick (gema oficial, antes stdlib).
require 'webrick'
require 'json'
require 'socket'

PORT = Integer(ENV['PORT'] || 8082)

server = WEBrick::HTTPServer.new(
  Port: PORT,
  BindAddress: '0.0.0.0',
  AccessLog: [], # Silenciamos access log, dejamos solo errores.
  Logger: WEBrick::Log.new($stdout, WEBrick::Log::WARN)
)

server.mount_proc '/health' do |_req, res|
  res.status = 200
  res.content_type = 'application/json; charset=utf-8'
  res.body = JSON.generate(status: 'ok', language: 'ruby')
end

server.mount_proc '/' do |req, res|
  if req.path != '/'
    res.status = 404
    res.content_type = 'text/plain; charset=utf-8'
    res.body = "not found\n"
    next
  end

  hostname = Socket.gethostname
  now = Time.now.utc.strftime('%Y-%m-%d %H:%M:%S')
  lang = "Ruby #{RUBY_VERSION} (p#{RUBY_PATCHLEVEL})"

  res.status = 200
  res.content_type = 'text/html; charset=utf-8'
  res.body = <<~HTML
    <!doctype html>
    <html lang="es">
    <head><meta charset="utf-8"><title>app-ruby - Actividad 1 UNIR</title>
    <style>body{font-family:system-ui,sans-serif;max-width:640px;margin:3rem auto;padding:0 1rem}h1{color:#CC342D}ul{line-height:1.8}code{background:#eee;padding:.1rem .3rem;border-radius:3px}</style>
    </head>
    <body>
      <h1>app-ruby</h1>
      <p>Microservicio de demostración para la Actividad 1 de Contenedores (Maestría DevOps - UNIR).</p>
      <ul>
        <li><strong>Lenguaje:</strong> <code>#{lang}</code></li>
        <li><strong>Hostname del contenedor:</strong> <code>#{hostname}</code></li>
        <li><strong>Fecha y hora del servidor (UTC):</strong> <code>#{now}</code></li>
        <li><strong>Health:</strong> <a href="/health">/health</a></li>
      </ul>
    </body>
    </html>
  HTML
end

%w[INT TERM].each do |sig|
  trap(sig) { server.shutdown }
end

puts "app-ruby listening on 0.0.0.0:#{PORT}"
server.start

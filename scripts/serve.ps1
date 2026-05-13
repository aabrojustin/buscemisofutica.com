# Tiny static file server for local preview.
# Usage: powershell -ExecutionPolicy Bypass -File scripts\serve.ps1 [port]
# Default port: 8080. Serves the project root.

param([int]$Port = 8080)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot

$mime = @{
  ".html" = "text/html; charset=utf-8"
  ".htm"  = "text/html; charset=utf-8"
  ".css"  = "text/css; charset=utf-8"
  ".js"   = "application/javascript; charset=utf-8"
  ".json" = "application/json; charset=utf-8"
  ".svg"  = "image/svg+xml"
  ".png"  = "image/png"
  ".jpg"  = "image/jpeg"
  ".jpeg" = "image/jpeg"
  ".gif"  = "image/gif"
  ".webp" = "image/webp"
  ".ico"  = "image/x-icon"
  ".txt"  = "text/plain; charset=utf-8"
  ".woff" = "font/woff"
  ".woff2"= "font/woff2"
}

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:$Port/")
$listener.Start()
Write-Host "Serving $root at http://localhost:$Port/"
Write-Host "Press Ctrl+C to stop."

try {
  while ($listener.IsListening) {
    $context = $null
    try {
      $context = $listener.GetContext()
      $req = $context.Request
      $res = $context.Response

      $relPath = [uri]::UnescapeDataString($req.Url.AbsolutePath.TrimStart('/'))
      if ([string]::IsNullOrEmpty($relPath)) { $relPath = "index.html" }
      $relPath = $relPath -replace '/', '\'

      $fullPath = Join-Path $root $relPath
      if (Test-Path $fullPath -PathType Container) {
        $fullPath = Join-Path $fullPath "index.html"
      }

      if (Test-Path $fullPath -PathType Leaf) {
        $ext = [System.IO.Path]::GetExtension($fullPath).ToLower()
        $contentType = if ($mime.ContainsKey($ext)) { $mime[$ext] } else { "application/octet-stream" }
        $bytes = [System.IO.File]::ReadAllBytes($fullPath)
        $res.ContentType = $contentType
        $res.StatusCode = 200
        $res.OutputStream.Write($bytes, 0, $bytes.Length)
        Write-Host "200 $relPath ($($bytes.Length) bytes)"
      } else {
        $res.StatusCode = 404
        $msg = [System.Text.Encoding]::UTF8.GetBytes("404: $relPath not found")
        $res.OutputStream.Write($msg, 0, $msg.Length)
        Write-Host "404 $relPath"
      }
    }
    catch {
      Write-Host "ERR: $_"
    }
    finally {
      if ($context -ne $null) {
        try { $context.Response.Close() } catch { }
      }
    }
  }
}
finally {
  $listener.Stop()
  $listener.Close()
}

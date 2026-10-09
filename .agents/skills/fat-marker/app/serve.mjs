#!/usr/bin/env node
// Serves the fat marker canvas, waits for one "Send to agent", writes the
// sketch, prints its outline to stdout and exits.
//
// Usage: node serve.mjs <out-dir> <name> [--no-open]
//
// Writes <out-dir>/<name>.tldr (the editable snapshot) and <out-dir>/<name>.png.
// If <name>.tldr already exists, the canvas opens with it so the sketch can be
// revised. stderr carries the URL; stdout carries only the outline.

import { execFile } from 'node:child_process'
import { randomBytes } from 'node:crypto'
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs'
import http from 'node:http'
import path from 'node:path'

const args = process.argv.slice(2)
const noOpen = args.includes('--no-open')
const [outDir, name] = args.filter((a) => !a.startsWith('--'))
if (!outDir || !name) die('usage: node serve.mjs <out-dir> <name> [--no-open]')
if (!/^[a-z0-9][a-z0-9-]*$/.test(name)) die(`name must be a lowercase slug: ${name}`)

const MAX_BODY = 25 * 1024 * 1024 // dropped photos are inlined in the snapshot
const PNG_MAGIC = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a])
const html = readFileSync(new URL('./index.html', import.meta.url))
const tldrPath = path.join(outDir, `${name}.tldr`)
const pngPath = path.join(outDir, `${name}.png`)
// The server listens on localhost, but any page in the browser can reach
// localhost. The token in the URL keeps them from writing files.
const token = randomBytes(16).toString('hex')

const server = http.createServer((req, res) => {
  const url = new URL(req.url, 'http://localhost')
  if (url.searchParams.get('t') !== token) return send(res, 403, 'bad token')
  if (req.method === 'GET' && url.pathname === '/') {
    return send(res, 200, html, 'text/html; charset=utf-8')
  }
  if (req.method === 'GET' && url.pathname === '/snapshot') {
    if (!existsSync(tldrPath)) return send(res, 404, 'no snapshot')
    return send(res, 200, readFileSync(tldrPath), 'application/json')
  }
  if (req.method === 'POST' && url.pathname === '/sketch') return receive(req, res)
  send(res, 404, 'not found')
})

function receive(req, res) {
  const chunks = []
  let size = 0
  req.on('data', (c) => {
    size += c.length
    if (size > MAX_BODY) {
      send(res, 413, 'sketch too large')
      req.destroy()
    } else chunks.push(c)
  })
  req.on('end', () => {
    if (res.writableEnded) return
    let body
    try {
      body = JSON.parse(Buffer.concat(chunks))
    } catch {
      return send(res, 400, 'body is not JSON')
    }
    const { snapshot, png, outline } = body
    const pngBytes = Buffer.from(String(png ?? '').replace(/^data:image\/png;base64,/, ''), 'base64')
    if (!snapshot || typeof snapshot !== 'object') return send(res, 400, 'missing snapshot')
    if (!pngBytes.subarray(0, 8).equals(PNG_MAGIC)) return send(res, 400, 'png is not a PNG')
    if (typeof outline !== 'string' || !outline.trim()) return send(res, 400, 'empty sketch')

    mkdirSync(outDir, { recursive: true })
    writeFileSync(tldrPath, JSON.stringify(snapshot))
    writeFileSync(pngPath, pngBytes)
    send(res, 200, 'sent')
    process.stdout.write(`# ${pngPath}\n${outline.trimEnd()}\n`)
    server.close()
    server.closeAllConnections()
  })
}

function send(res, status, body, type = 'text/plain; charset=utf-8') {
  res.writeHead(status, { 'content-type': type })
  res.end(body)
}

function die(msg) {
  process.stderr.write(msg + '\n')
  process.exit(2)
}

server.listen(0, '127.0.0.1', () => {
  const url = `http://127.0.0.1:${server.address().port}/?t=${token}`
  process.stderr.write(`fat marker canvas: ${url}\n`)
  if (noOpen) return
  const [cmd, ...pre] =
    process.platform === 'darwin' ? ['open'] : process.platform === 'win32' ? ['cmd', '/c', 'start', ''] : ['xdg-open']
  execFile(cmd, [...pre, url], (err) => err && process.stderr.write(`open the URL above: ${err.message}\n`))
})

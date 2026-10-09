// Smoke check for serve.mjs: node --test .agents/skills/fat-marker/app/serve.test.mjs
// The canvas itself (index.html) is checked by hand; see the skill's
// "Changing the app" section.

import assert from 'node:assert/strict'
import { spawn } from 'node:child_process'
import { existsSync, mkdtempSync, readFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import path from 'node:path'
import test from 'node:test'
import { fileURLToPath } from 'node:url'

const serve = fileURLToPath(new URL('./serve.mjs', import.meta.url))
const PNG = 'data:image/png;base64,' + Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0]).toString('base64')

function start(out) {
  const proc = spawn(process.execPath, [serve, out, 'sketch', '--no-open'])
  let stdout = ''
  proc.stdout.on('data', (d) => (stdout += d))
  const exited = new Promise((resolve) => proc.on('exit', (code) => resolve({ code, stdout })))
  const url = new Promise((resolve) => {
    let err = ''
    proc.stderr.on('data', (d) => {
      err += d
      const m = err.match(/http:\/\/\S+/)
      if (m) resolve(new URL(m[0]))
    })
  })
  return { proc, url, exited }
}

const post = (url, body) =>
  fetch(new URL(`/sketch?t=${url.searchParams.get('t')}`, url), {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify(body),
  })

test('serves the canvas, rejects bad input, writes the sketch and exits', async () => {
  const out = path.join(mkdtempSync(path.join(tmpdir(), 'fat-marker-')), 'sketches')
  const { url, exited } = start(out)
  const u = await url

  assert.equal((await fetch(u)).status, 200)
  assert.equal((await fetch(new URL('/', u))).status, 403, 'no token')
  assert.equal((await fetch(new URL(`/snapshot?t=${u.searchParams.get('t')}`, u))).status, 404)

  assert.equal((await post(u, { snapshot: {}, png: 'data:image/png;base64,AAAA', outline: 'x' })).status, 400)
  assert.equal((await post(u, { snapshot: {}, png: PNG, outline: '  ' })).status, 400)
  assert.ok(!existsSync(path.join(out, 'sketch.png')), 'a rejection writes nothing')

  const ok = await post(u, { snapshot: { document: 1 }, png: PNG, outline: 'rectangle 1 "a"\n' })
  assert.equal(ok.status, 200)

  const { code, stdout } = await exited
  assert.equal(code, 0)
  assert.equal(stdout, `# ${path.join(out, 'sketch.png')}\nrectangle 1 "a"\n`)
  assert.deepEqual(JSON.parse(readFileSync(path.join(out, 'sketch.tldr'))), { document: 1 })
  assert.ok(readFileSync(path.join(out, 'sketch.png')).subarray(0, 4).equals(Buffer.from([0x89, 0x50, 0x4e, 0x47])))
})

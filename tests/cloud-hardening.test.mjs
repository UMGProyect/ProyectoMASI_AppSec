import test from 'node:test';
import assert from 'node:assert/strict';
import worker from '../worker.mjs';

test('HTTP redirige a HTTPS sin entregar assets y conserva path y query', async () => {
  const req = new Request('http://premier.example/reports?period=1');
  const res = await worker.fetch(req, { ASSETS: { fetch() { assert.fail('No debe servir HTTP'); } } });
  assert.equal(res.status, 308);
  assert.equal(res.headers.get('location'), 'https://premier.example/reports?period=1');
  assert.equal(await res.text(), '');
});

test('HTTPS conserva el asset y aplica las cabeceras', async () => {
  const req = new Request('https://premier.example/');
  const res = await worker.fetch(req, { ASSETS: { async fetch() {
    return new Response('ok', {headers: {'Content-Type': 'text/html'}});
  } } });
  assert.equal(res.status, 200);
  assert.equal(await res.text(), 'ok');
  assert.equal(res.headers.get('content-type'), 'text/html');
  assert.equal(res.headers.get('strict-transport-security'), 'max-age=31536000');
  assert.equal(res.headers.get('x-frame-options'), 'DENY');
  const csp = res.headers.get('content-security-policy');
  assert.match(csp, /frame-ancestors 'none'/);
  assert.match(csp, /object-src 'none'/);
  assert.match(csp, /https:\/\/\*\.supabase\.co/);
  assert.doesNotMatch(csp, /script-src[^;]*unsafe-inline|unsafe-eval/);
});

test('HEAD y 304 preservan el estado sin cuerpo', async () => {
  const res = await worker.fetch(new Request('https://premier.example/', {method:'HEAD'}), {
    ASSETS: { async fetch() { return new Response(null, {status:304}); } }
  });
  assert.equal(res.status, 304);
  assert.equal(await res.text(), '');
  assert.ok(res.headers.get('strict-transport-security'));
});

// ====================================================================
// TEMPORAL — endpoint para el ESP32:  POST /verificacionesp32  ->  "1" o "0"
//
// PARA CAMBIAR EL VALOR: edite ESTADO aquí abajo (1 o 0) y haga commit en GitHub.
// Cloudflare vuelve a desplegar solo; el cambio se ve en uno o dos minutos.
//
// PARA ELIMINARLO TODO: borrar este archivo y quitar "main" y "binding" de
// wrangler.jsonc, o simplemente hacer `git revert` del commit que lo agregó.
// ====================================================================
const ESTADO = 0; // 1 = encender, 0 = no hacer nada (cualquier otro valor se trata como 0)

const RUTA = '/verificacionesp32';

export default {
  async fetch(request, env) {
    const { pathname } = new URL(request.url);

    if (pathname.replace(/\/+$/, '') === RUTA) {
      const headers = { 'Cache-Control': 'no-store', 'X-Content-Type-Options': 'nosniff' };
      if (request.method !== 'POST') {
        return new Response('Method Not Allowed', { status: 405, headers: { ...headers, Allow: 'POST' } });
      }
      return new Response(ESTADO === 1 ? '1' : '0', {
        status: 200,
        headers: { ...headers, 'Content-Type': 'text/plain; charset=utf-8' },
      });
    }

    // Todo lo demás: la app estática, exactamente como antes
    return env.ASSETS.fetch(request);
  },
};

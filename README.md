# Centro Médico Premier

Frontend estático (HTML + JS modular) con Supabase como backend. Sin dependencias de build.

## Variables de entorno (en el hosting)
| Variable | Descripción |
|---|---|
| `SUPABASE_URL` | URL del proyecto (`https://xxxx.supabase.co`) |
| `SUPABASE_ANON_KEY` | Clave `anon public` (pública por diseño; la seguridad la dan las políticas RLS) |
| `CONSULTATION_FEE` | Tarifa de consulta en quetzales (opcional, por defecto 150) |

Nunca uses la `service_role` key en el frontend ni en estas variables.

## Despliegue gratuito en Cloudflare Pages
1. Cloudflare Dashboard → **Workers & Pages → Create → Pages → Connect to Git** → elige este repo.
2. Framework preset: **None**. Build command: `node build.js`. Build output directory: `dist`.
3. En **Environment variables** agrega las tres variables de arriba.
4. **Save and Deploy**. Cada push a `main` redespliega.

Funciona igual en Vercel (usa `vercel.json`) con las mismas variables.

## Supabase
En **Authentication → URL Configuration** pon la URL del sitio desplegado como *Site URL* y agrégala en *Redirect URLs*.

## Desarrollo local
Coloca tu `config.js` en la raíz (está en `.gitignore`) y ejecuta `npm start`.

## Seguridad: verificación en dos pasos (MFA)
Aplicación autenticadora (TOTP) con Supabase Auth. Obligatoria para el personal y opcional para pacientes.
1. En Supabase: Authentication → Multi-Factor → TOTP habilitado.
2. Cada usuario la activa en **Seguridad de la cuenta** dentro de la app.
3. Cuando todo el personal la haya activado, ejecutar `Supabase/mfa.sql` en el SQL Editor (reversa: `Supabase/mfa_rollback.sql`).

Detalle, pruebas y limitaciones: [`docs/ficha-mfa-totp.md`](docs/ficha-mfa-totp.md).

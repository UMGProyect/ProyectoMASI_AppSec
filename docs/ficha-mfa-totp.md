# Ficha de control: verificación en dos pasos (MFA) con aplicación autenticadora

**Sistema:** Centro Médico Premier (frontend estático + Supabase + Cloudflare)  
**Control:** segundo factor TOTP (RFC 6238) con Supabase Auth, exigido en el servidor mediante RLS  
**Rama / commit:** `mfa-autenticador`

## 1. Amenaza que cubre
Acceso no autorizado a historiales clínicos, recetas y facturación mediante una contraseña robada, adivinada o reutilizada (phishing, relleno de credenciales, filtraciones de otros sitios). Con el segundo factor, la contraseña por sí sola ya no basta.

## 2. Control y referencias
| Marco | Referencia |
|---|---|
| ISO/IEC 27002:2022 | 8.5 Autenticación segura |
| OWASP ASVS | Capítulo de autenticación: verificadores de un solo uso (OTP) y multifactor |
| NIST SP 800-63B | Nivel de garantía de autenticador AAL2 |

*(Verificar la numeración exacta contra la edición vigente de cada documento antes de citarla.)*

## 3. Cómo está implementado
| Capa | Qué hace | Archivo |
|---|---|---|
| Activación | Pantalla "Seguridad de la cuenta": QR + clave manual, confirmación con un código de 6 dígitos. Desactivar exige un código vigente. | `js/security.js` |
| Inicio de sesión | Tras correo y contraseña, si hay autenticador se pide el código antes de mostrar la app (sesión `aal1` → `aal2`). Cancelar libera la sesión registrada. | `js/login.js`, `js/app.js` |
| Obligatoriedad | Personal (admin, médico, enfermería, farmacia, caja): sin autenticador solo puede abrir "Seguridad de la cuenta". Pacientes: opcional. | `js/app.js` |
| **Servidor (RLS)** | Política **restrictiva** `mfa_aal2` en las tablas sensibles: el personal necesita sesión `aal2`. No modifica las políticas existentes. | `Supabase/mfa.sql` |
| Reversa | Quita políticas y función auxiliar. | `Supabase/mfa_rollback.sql` |
| Auditoría | Se registran `mfa_enabled` y `mfa_disabled` en `audit_logs`. | `js/security.js` |

**Por qué RLS:** un control que solo vive en el navegador se puede saltar llamando a la API de Supabase directamente (la clave `anon` es pública). La política hace que, aunque alguien tenga la contraseña, los datos no se entreguen sin el segundo factor.

## 4. Pruebas
**Hechas (26 comprobaciones en navegador, con Supabase simulado):** personal sin autenticador es llevado a activarlo y no puede abrir otras rutas; el QR se dibuja; código incorrecto rechazado con mensaje en español; activación registra auditoría; login pide el código y no muestra la app sin él; validación de formato; cancelar cierra la sesión parcial; el personal no puede desactivar; el paciente puede activar y desactivar con código; sin desbordes en móvil.

**Pendientes en el Supabase real (hacerlas y anotar el resultado en el informe):**
1. Activar el autenticador de un administrador con una app real y cerrar sesión.
2. Iniciar sesión: contraseña correcta + código correcto → entra; código incorrecto → no entra.
3. Ejecutar `Supabase/mfa.sql`. Con el token de una sesión **solo con contraseña** (`aal1`) de un usuario de personal, consultar `GET /rest/v1/patients`: debe devolver `[]`. Con una sesión `aal2`: devuelve filas.
4. Probar la reversa (`mfa_rollback.sql`) y volver a aplicar.

## 5. Limitaciones y riesgo residual
- **Sin códigos de recuperación.** Si alguien pierde el teléfono, un administrador del proyecto debe desvincular su factor en el panel de Supabase.
- **La primera activación depende solo de la contraseña.** Quien robe la contraseña de una cuenta de personal que nunca activó el autenticador podría activar el suyo. Mitigación: activar todas las cuentas de personal desde el primer día.
- **Funciones `SECURITY DEFINER`** (dispensar, facturar, reportes, recibir órdenes) no pasan por RLS; exigir `aal2` ahí requiere añadir una comprobación en cada función.
- **TOTP no resiste phishing en tiempo real** (proxy que reenvía el código). La mejora natural son llaves de acceso (passkeys/WebAuthn).
- **Fuerza bruta de códigos:** limitada por los límites de tasa de Supabase Auth; no se ajustaron aquí.
- **Sesión única:** la sesión se registra antes de verificar el código; el token de actualización cambia al subir a `aal2`. Conviene confirmar que `heartbeat_session` no dependa de ese identificador.

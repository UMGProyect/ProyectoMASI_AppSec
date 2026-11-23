# Integracion segura de cambios

- Trabajar en develop (o ramas de trabajo desde develop). Publicar cambios y revisar los resultados de GitHub Actions.
- SAST: Semgrep en modo bloqueante con reglas JavaScript y OWASP Top Ten. Se excluyen artefactos de evidencias del informe, node_modules y dist; no se afirma cobertura de todos los lenguajes.
- Secretos: Gitleaks conserva sus reglas por defecto y agrega deteccion de asignaciones literales a variables sensibles. Analiza el historial alcanzable desde HEAD, incluidos los commits del PR; la excepcion existente de reCAPTCHA conserva su fingerprint exacto.
- SCA: analisis CDN mediante OSV (se bloquean avisos aplicables y errores de consulta). La falta de SRI se reporta como observacion.
- Security Gate (integracion): solo pasa si los tres jobs concluyen success; cualquier otro resultado bloquea el gate.
- Para produccion, habilitar Ruleset activo sobre main, exigir PR y el check Security Gate (integracion) de GitHub Actions, exigir actualizacion respecto de la rama destino, sin bypass ordinario. Proteger la modificacion de workflows y reglas de escaneo mediante revision independiente cuando exista un revisor.
- Cloudflare: rama de produccion main. Desactivar Preview Builds automaticos mientras no exista un entorno de desarrollo independiente con datos de prueba y despliegue condicionado.
- La rama demo/security-gate se conserva como laboratorio. No fusionarla. No introducir credenciales reales ni ficticias de prueba en develop o main: borrar un literal no borra su commit del historial. Ante exposicion real, revocar/rotar y gestionar el incidente.
- El gate no despliega ni modifica Cloudflare. El despliegue de produccion sigue a un merge autorizado en main; hasta activar el Ruleset, GitHub Actions informa del fallo pero no impide un merge por si solo.

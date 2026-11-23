# Demostracion controlada de Security Gate

Rama exclusiva: `demo/security-gate`. No integrar a main.

1. Confirmar en Cloudflare Workers > Settings > Build > Branch control que la rama de produccion es main y que los Preview builds estan desactivados para impedir construcciones externas al gate.
2. Abrir demo/security-test.js en VS Code. Para la prueba negativa, sustituir la linea por una asignacion de SUPABASE_DB_PASSWORD con un valor ficticio que empiece por DEMO_ONLY_. Nunca emplear credenciales reales.
3. Guardar, commit y push a esta rama. Abrir Actions > Security Gate (demo). Se espera fallo de Gitleaks, fallo de Security Gate y Deploy (Simulacion) omitido.
4. Restaurar el contenido inicial del JS, commit y push. Se espera que Gitleaks supere el control y, si los demas escaneres no encuentran bloqueos ni errores, que el gate y el despliegue simulado sean satisfactorios.

Alcance: Semgrep y Gitleaks inspeccionan la carpeta demo/ en el estado actual; Gitleaks conserva reglas por defecto y una regla personalizada. SCA conserva el inventario CDN del proyecto. No es un analisis integral del historial ni sustituye los controles originales de main. Borrar una credencial real de un archivo no elimina su exposicion del historial. El job de despliegue solo emite mensajes, no realiza despliegues. El control no intercepta la integracion Git de Cloudflare ni impide el push a la rama.

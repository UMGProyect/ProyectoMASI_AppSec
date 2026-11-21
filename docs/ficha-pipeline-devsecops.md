# Ficha: pipeline DevSecOps (SAST, SCA, secretos y DAST)

**Fase del reto:** 3 (Desarrollo y DevSecOps) y 4 (Ciberdefensa, caja negra).

## Amenazas que atiende
| ID | Amenaza | Control |
| --- | --- | --- |
| T-08 | XSS almacenado por `innerHTML` | SAST con Semgrep (reglas de JavaScript y OWASP Top 10) |
| T-09 | Cadena de suministro: scripts de CDN sin SRI y versiones vulnerables | SCA contra OSV (`.github/scripts/sca_cdn.py`) y revisión de SRI |
| T-14 | Secretos expuestos | Gitleaks sobre todo el historial; Semgrep `p/secrets` |
| T-01, T-13 | Debilidades visibles desde el exterior (cabeceras, cookies, captcha) | OWASP ZAP baseline contra el sitio desplegado |

## Qué se implementó
- `.github/workflows/security.yml`: se ejecuta en cada push y pull request. Tres trabajos independientes (SAST, secretos, SCA).
- `.github/workflows/zap-baseline.yml`: ejecución manual; ZAP en modo pasivo contra `SITE_URL`.
- Los reportes quedan como artefactos de cada ejecución y un resumen en el panel de la ejecución.

## Decisión de diseño: primera versión no bloqueante
La primera corrida es una línea base ("antes"): los trabajos usan `continue-on-error` para registrar los hallazgos sin impedir los cambios. Tras corregirlos se quita esa opción y el pipeline pasa a bloquear el merge ante nuevos problemas. Se combina con una regla de protección de la rama `main` que exige que los checks pasen.

## Limitaciones
- Semgrep y Retire/OSV detectan problemas conocidos; no reemplazan una revisión manual (caja gris/blanca).
- ZAP baseline es pasivo: no ejecuta ataques activos ni prueba áreas que requieren sesión.
- El SCA de dependencias por CDN depende de la base OSV; SheetJS publica versiones recientes fuera de npm y su cobertura puede ser parcial.
- Las acciones se fijan por versión mayor; fijarlas por hash del commit reduciría el riesgo de cadena de suministro del propio pipeline.

## Estándares
ISO/IEC 27002:2022 (8.25 ciclo de vida de desarrollo seguro, 8.28 codificación segura, 8.29 pruebas de seguridad), OWASP SAMM, OWASP Top 10 (A06 componentes vulnerables).

# Observación 2.4 — Alcance efectivo de Trivy
Fuente: informe base, sección 3.7, Tabla 25; observación 2.4. Diagnóstico histórico: 23/11/2026 04:42 UTC (según informe).
Trivy filesystem sobre árbol de trabajo, excluyendo .git; 29 rutas distintas según escáner streaming. SHA exacto no identificado (cambios locales); dist no escaneado; versión remota anunciada 0.76.2 no demuestra versión instalada.

| Modalidad | Resultado | Interpretación |
|---|---|---|
| Secret | Sin detecciones | Solo en alcance inspeccionado |
| Vulnerability | 0 archivos compatibles | Sin cobertura efectiva |
| Misconfiguration | 0 archivos compatibles | Sin cobertura efectiva de IaC |

No se identificaron imágenes productivas, Kubernetes o Terraform en la arquitectura original de servicios gestionados. Docker es herramienta de análisis, no runtime productivo. Se justifica excluir modalidades sin objetivo identificado, no inferir ausencia de riesgos. PR #16 añadió Worker y modificó wrangler.jsonc posteriormente; el escaneo histórico no cubre automáticamente la nueva versión. Semgrep, OSV/SCA, Gitleaks y revisión Cloud son complementarios, no amplían retroactivamente Trivy. [Evidencias históricas EV-F05-TRIVY-001a/001b](https://github.com/UMGProyect/ProyectoMASI_AppSec/tree/16f6d806b8a91c26cc04edf132c1b6a92a8d2654/docs/proyecto-final/Evidencias/Fase-05-CloudSec/Evaluaci%C3%B3n%20CloudSec); se localizó su existencia, no se inspeccionaron píxeles ni logs completos. No se ejecutó un escaneo nuevo.

# Verificación de autorización por objeto — migración 05

Fecha UTC: 2026-11-28 03:56:51.749108. Fecha local Guatemala: 27-11-2026 21:56:51.
Migración aplicada sin errores reportados en SQL Editor y código integrado en [PR #20](https://github.com/UMGProyect/ProyectoMASI_AppSec/pull/20), commit d7d61698c1d45dbc935c92fe1c71b772ddca7066.

Método: prueba SQL aportada por el responsable, con selección previa de registros existentes, SET LOCAL ROLE authenticated, atributos JWT simulados para médico AAL2/AAL1, paciente AAL1 y administrador AAL2, ROLLBACK. No equivale a solicitudes HTTP reales ni a autenticación TOTP real. Las operaciones de escritura de prueba no persisten.

| Prueba | Resultado esperado | Resultado observado |
|---|---|---|
| RLS-01 | perfil propio permitido | true |
| RLS-02 | perfil ajeno bloqueado | true |
| RLS-03 | paciente asignado permitido | true |
| RLS-04 | paciente ajeno bloqueado | true |
| RLS-05 | edicion ajena bloqueada | true |
| RLS-06 | autoasignacion bloqueada | true |
| RLS-07 | asociacion protegida | true |
| RLS-08 | expediente propio permitido | true |
| RLS-09 | expediente ajeno bloqueado | true |
| RLS-10 | rpc clinica bloqueada | true |
| RLS-11 | directorio medico disponible | true |
| RLS-12 | medico aal1 bloqueado | true |
| RLS-13 | admin acceso permitido | true |

13/13 casos satisfactorios según salida SQL aportada. Se mantuvieron activos RLS y MFA; acceso de médico a perfil ajeno y paciente no asignado pasó de permitido a bloqueado. El perfil propio en AAL1 y el directorio mínimo para paciente permanecieron disponibles. La prueba de asociación de cita recibió el mensaje específico del trigger. La prueba de modificación ajena afectó cero filas; el intento de inserción de cita ajena recibió 42501. El rechazo de la RPC clínica al paciente se comprobó por mensaje de autorización.

## Límites

La muestra contiene un médico con rol activo y pacientes relacionados/no relacionados; no acredita todos los pares de médicos ni acceso HTTP con JWT reales. No se verificaron todos los roles de personal, operaciones legítimas de escritura, nombres históricos, vigencia de relaciones ni regresión completa de interfaz. Enfermería y caja conservan acceso amplio operativo y farmacia requiere pruebas adicionales. No se declara eliminación total de AM-08/AM-09 ni aceptación formal. La reducción del riesgo es una estimación que debe reflejar estas limitaciones.

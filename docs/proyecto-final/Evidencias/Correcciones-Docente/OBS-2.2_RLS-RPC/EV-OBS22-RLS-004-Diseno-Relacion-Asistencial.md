# Autorización por objeto — diseño de migración 05
Estado: propuesto/versionado; aplicación y verificación posterior pendientes.
- profiles_sel: perfil propio incluso AAL1 para el flujo MFA; administradores AAL2 acceden a otros perfiles. RPC list_doctors y profile_display_names solo devuelven id/nombre, con selección contextual y AAL2 para personal.
- pat_sel/pat_upd: médico AAL2 accede a pacientes con cita o consulta histórica propia o alta de expediente propia. Se conserva el flujo de alta médica sin cuenta vinculada; no puede adoptar expedientes existentes. Citas históricas (incluidas canceladas/ausentes) cuentan como relación; revisión de vigencia y procedencia histórica pendiente.
- apt_ins: médico no puede crear una relación mediante cita con un paciente ajeno. Paciente puede solicitar su propia cita con médico activo; admin/enfermería asignan pacientes.
- Triggers BEFORE UPDATE: impiden al médico cambiar claves de asociación de expedientes, citas y consultas. Se mantienen triggers de auditoría y restricciones MFA.
- Farmacia: pacientes con recetas; enfermería y caja mantienen permisos amplios por operación existente. La minimización de atributos y autorización contextual para esos roles sigue pendiente. No se afirma cierre integral de AM-09.
- Los módulos de citas, expedientes, consulta, dashboard y farmacia solicitan nombres a RPC de directorio en lugar de leer perfiles completos.
- Despliegue: aplicar migración 05 en SQL Editor, comprobar RLS y desplegar frontend coordinadamente. Durante la transición el frontend anterior no puede recuperar algunos nombres o directorio; no repetir migraciones 01–04. Verificar login, MFA, selección de médicos, agenda, expediente y farmacia. Revertir mediante cambio coordinado si hay regresión; no restaurar indiscriminadamente el acceso global.
- El caso negativo AAL2 previo está en EV-OBS22-RLS-001-Autorizacion-Antes.txt. No se ha ejecutado esta migración ni las pruebas posteriores.

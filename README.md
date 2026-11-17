# Práctica de Claude Code con SSIS

Contoso Retail necesita cargar CSV de ventas, registrar los rechazos y reprocesar archivos sin duplicar datos. El alumno parte de un paquete existente y añade la normalización del cliente a mayúsculas. Sigue la guía Practica_Claude_Code_SSIS.docx desde el principio.

## Aula con una VM de Azure

- En la VM se ejecuta SQL Server 2022 y se guardan los CSV. El docente habilita el acceso SQL por TCP y comprueba el login compartido sa.
- El docente extrae el ZIP en la VM y lanza scripts/Preparar-Aula.ps1 -Cantidad 12, ajustando la cifra. Crea carpetas con muestras para la base principal y de pruebas de cada alumno. La cuenta del servicio SQL debe poder leer esos CSV.
- Cada alumno trabaja en su Windows local con el runtime SSIS 2022 de 64 bits, OLE DB Driver 18 (MSOLEDBSQL), sqlcmd, VS Code, Claude Code y Git. Se conecta a la VM desde los scripts con -Servidor, -Credencial y -BaseDatos. El paso 5 incluye los comandos.
- El docente asigna el número. El alumno 01 usa ClaudeETLLab_Alumno01 y ClaudeETLLab_Alumno01_Pruebas. Preparar.ps1 crea la base seleccionada si falta e instala tablas y procedimiento. Ejecutar.ps1 llama al DTExec local. Consultar.ps1 muestra el resultado en esa misma base.
- Los CSV de aula están en C:LabSSISdata<base> en la VM. El procedimiento usa OPENROWSET y BULK INSERT sobre archivos del servidor. Para probar un CSV propio, el docente debe copiarlo a la carpeta correspondiente de la VM.
- El login compartido sa tiene acceso a todas las bases. Los nombres y el chequeo de destino organizan el laboratorio y evitan errores de uso. Introduce la contraseña con Get-Credential. El paquete temporal que usa DTExec contiene la conexión durante la ejecución, vive fuera del repositorio y el script lo elimina al terminar.
- Si la VM de aula presenta un certificado no confiable, el parámetro -ConfiarCertificadoLaboratorio mantiene el cifrado y omite la validación del certificado para esa conexión.

## Laboratorio individual en un solo Windows

Los scripts conservan autenticación de Windows y el nombre ClaudeETLLab si se omiten -Credencial y -BaseDatos. Extrae el kit completo y coloca el CSV en C:LabSSISdataentas.csv. Desde la raíz ejecuta:

```powershell
.scriptsPreparar.ps1 -Servidor localhost
.scriptsEjecutar.ps1 -Servidor localhost -ArchivoServidor 'C:LabSSISdataentas.csv'
.scriptsConsultar.ps1 -Servidor localhost
```

La primera carga de la muestra devuelve 12 filas leídas, 5 ventas por 149.99 y 7 rechazos. La repetición registra otra ejecución con 0 ventas insertadas y 0 actualizadas. -SoloValidar valida el paquete sin ejecutar la carga.

## Pruebas y CI

Test-Integracion.ps1 exige el cambio a mayúsculas y una base ya preparada y vacía. En el aula usa el sufijo _Pruebas. Usa las muestras de esa carpeta para los cuatro cuadrantes. GitHub Actions hospedado ejecuta Test-Estatico.ps1 sin acceder a la VM ni usar credenciales SQL. El workflow manual de SSIS es una ampliación para otro entorno aislado, con conexión Windows y la base individual por defecto.

El DTSX orquesta tres tareas Execute SQL. La lógica de carga sigue en T-SQL. El destino Azure SQL Database requiere adaptar la lectura de archivos. La ejecución real en la VM de aula se valida siguiendo los pasos 5 y 12 de la guía.

Documentacion oficial consultada el 10 de noviembre de 2026:
- https://code.claude.com/docs/en/memory
- https://code.claude.com/docs/en/skills
- https://code.claude.com/docs/en/sub-agents
- https://code.claude.com/docs/en/plugins/create
- https://learn.microsoft.com/en-us/sql/integration-services/packages/dtexec-utility?view=sql-server-ver16
- https://learn.microsoft.com/en-us/sql/integration-services/control-flow/execute-sql-task?view=sql-server-ver16
- https://docs.github.com/en/get-started/using-github/github-flow
- https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches
- https://docs.github.com/en/actions/reference/security/secure-use
- https://docs.github.com/en/actions/concepts/security/workflow-dependency-lockfiles
- https://docs.github.com/en/code-security/concepts/secret-security/push-protection
- https://github.com/actions/checkout/commit/3d3c42e5aac5ba805825da76410c181273ba90b1
- https://agiletester.ca/applying-the-agile-testing-quadrants-to-continuous-delivery-and-devops-culture-part-1-working-towards-continuous-delivery/
- https://learn.microsoft.com/en-us/sql/integration-services/load-data-to-sql-database-with-ssis?view=sql-server-ver16
- https://learn.microsoft.com/en-us/sql/t-sql/statements/bulk-insert-transact-sql?view=sql-server-ver16
- https://learn.microsoft.com/en-us/azure/data-factory/concepts-integration-runtime

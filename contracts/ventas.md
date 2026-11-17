# Contrato de carga de ventas

Describe el comportamiento esperado de `dbo.usp_CargarVentas` (`sql/02_Procedimiento.sql`), invocado desde `ssis/CargarVentas.dtsx`. Cualquier cambio del ETL debe respetar este contrato o actualizarlo de forma explícita. Señala diferencias con el código antes de modificarlo.

## Archivo de entrada
- Formato CSV, codificación UTF-8, separador `;`.
- Cabecera exacta: `VentaId;Fecha;Cliente;Cantidad;Precio`.
- Cinco campos por fila.
- La ruta se limita a la carpeta de laboratorio del servidor SQL: `C:\LabSSIS\data\` para `ClaudeETLLab`, y `C:\LabSSIS\data\<NombreBase>\` para el resto de bases. Solo se admiten archivos `.csv`, sin `..`, `/` ni `:` adicionales.

## Reglas de validación por fila
| Campo | Regla | Motivo de rechazo |
|---|---|---|
| VentaId | Entero positivo | `VentaId invalido` |
| Fecha | Formato exacto `yyyy-MM-dd` | `Fecha invalida` |
| Cliente | Obligatorio tras quitar espacios; máximo 100 caracteres. Se guarda en MAYÚSCULAS conservando acentos (`María` → `MARÍA`) | `Cliente invalido` |
| Cantidad | Entero de 1 a 100000 | `Cantidad invalida` |
| Precio | De 0.01 a 1000000, punto decimal, hasta dos decimales | `Precio invalido` |
| Clave | Si un VentaId aparece más de una vez en el archivo, se rechazan todas sus apariciones | `VentaId duplicado en el archivo` |

Si una fila incumple varias reglas, se registra un único motivo: el primero según el orden de la tabla.

## Carga en destino (`dbo.Ventas`)
- `Importe = Cantidad * Precio`, almacenado como `decimal(18,2)`.
- Las ventas nuevas se insertan.
- Las ventas existentes se actualizan solo si cambia algún dato (Fecha, Cliente, Cantidad o Precio). Una recarga idéntica produce 0 insertadas y 0 actualizadas.
- Cliente se normaliza con `UPPER` sobre el valor sin espacios, con intercalación `Latin1_General_100_CI_AS`. El staging conserva el valor original.
- Al desplegar esta regla sobre una base con datos, la primera recarga actualiza las ventas cuyo Cliente no estaba en mayúsculas; las siguientes dan 0 actualizadas.

## Trazabilidad
- Cada ejecución queda en `dbo.Ejecuciones` con Leidas, Aceptadas, Rechazadas, Insertadas y Actualizadas.
- Se cumple que `Leidas = Aceptadas + Rechazadas` y que `Insertadas + Actualizadas <= Aceptadas`.
- Se conservan el staging (`dbo.StagingVentas`) y los motivos de rechazo (`dbo.Rechazos`).
- `Fila` identifica el registro de staging dentro de la ejecución, no el número de línea del CSV.

## Errores técnicos
- Un fallo técnico revierte la carga completa y registra la ejecución con estado `ERROR` y su mensaje.

## Cambio
Explica el problema, el comportamiento resultante y el issue relacionado.

## Comprobaciones realizadas
Indica comandos ejecutados, resultados y commit comprobado. Distingue pruebas
locales, CI, SSIS y revisiones humanas. Marca como pendiente lo que no ejecutaste.
Relaciona las pruebas con Q1, Q2, Q3 y Q4 cuando corresponda al cambio.

## Autorrevision individual
Revisa Files changed y contrasta los hallazgos de los subagentes. Registra lo
corregido y lo pendiente. Esta practica no exige otra persona ni aprobacion de
la propia PR; los checks y las conversaciones deben quedar resueltos.

## Seguridad
Explica los permisos, entradas o dependencias afectados. Confirma la revision de
secretos y datos del diff. Si no aplica, indica por que.

## Operacion y recuperacion
Describe el efecto sobre datos existentes, la actualizacion del procedimiento y
como revertir el codigo. Explica como recuperar datos si el cambio los modifica.

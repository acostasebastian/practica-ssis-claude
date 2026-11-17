---
name: revisar-etl
description: Revisa el ETL y sus riesgos frente al contrato
disable-model-invocation: true
---
Lee CLAUDE.md y contracts/ventas.md.
Revisa los archivos indicados en $ARGUMENTS.
Comprueba tipos, rechazos, duplicados e idempotencia.
Revisa parametros, precedencias, TLS y rutas.
No edites ni ejecutes SQL, DTExec o acciones remotas.
Devuelve hallazgo, archivo, impacto y cambio propuesto.
Relaciona las pruebas afectadas con Q1 a Q4.
No inventes resultados de pruebas.

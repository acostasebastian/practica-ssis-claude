SELECT * FROM dbo.Ventas ORDER BY VentaId;
SELECT COUNT(*) AS Ventas, SUM(Importe) AS ImporteTotal FROM dbo.Ventas;
SELECT * FROM dbo.Ejecuciones ORDER BY Inicio DESC;
SELECT s.*,r.Motivo FROM dbo.Rechazos r JOIN dbo.StagingVentas s
 ON r.RunId=s.RunId AND r.Fila=s.Fila ORDER BY s.RunId,s.Fila;

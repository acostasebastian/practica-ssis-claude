CREATE OR ALTER PROCEDURE dbo.usp_CargarVentas @Archivo nvarchar(4000)
AS
BEGIN
 SET NOCOUNT ON;
 SET XACT_ABORT ON;
 IF @Archivo IS NULL OR LEN(@Archivo)=0 OR LEN(@Archivo)>3500
   THROW 51000, 'Ruta de archivo no valida.', 1;
 -- Cada base de aula tiene su carpeta de entrada en el servidor SQL.
 DECLARE @Directorio nvarchar(4000)=N'C:\LabSSIS\data\';
 IF DB_NAME()<>N'ClaudeETLLab' SET @Directorio+=DB_NAME()+N'\';
 IF LEFT(@Archivo,LEN(@Directorio)) COLLATE Latin1_General_100_BIN2<>@Directorio COLLATE Latin1_General_100_BIN2
   OR RIGHT(@Archivo,4) COLLATE Latin1_General_100_BIN2<>N'.csv'
   OR CHARINDEX(N'..',@Archivo)>0 OR CHARINDEX(N'/',@Archivo)>0
   OR CHARINDEX(N':',@Archivo,3)>0
   THROW 51003, 'Solo se admiten archivos CSV del directorio de laboratorio.', 1;
 DECLARE @RunId uniqueidentifier=NEWID(), @Lock int,
         @Leidas int, @Aceptadas int, @Insertadas int, @Actualizadas int;
 INSERT dbo.Ejecuciones(RunId,Archivo,Estado) VALUES(@RunId,@Archivo,'INICIADA');
 BEGIN TRY
  BEGIN TRANSACTION;
  EXEC @Lock=sys.sp_getapplock @Resource=N'ClaudeETLLab_CargaVentas',
   @LockMode='Exclusive', @LockOwner='Transaction', @LockTimeout=10000;
  IF @Lock<0 THROW 51001,'Hay otra carga en curso.',1;

  -- El archivo lo lee SQL Server desde SU sistema de archivos.
  CREATE TABLE #Raw (VentaId nvarchar(100), Fecha nvarchar(100),
    Cliente nvarchar(400), Cantidad nvarchar(100), Precio nvarchar(100));
  DECLARE @HeaderSql nvarchar(max)=N'DECLARE @Contenido varchar(max);
    SELECT @Contenido=BulkColumn FROM OPENROWSET(BULK '''+
    REPLACE(@Archivo,'''','''''')+N''', SINGLE_CLOB, CODEPAGE=''65001'') AS origen;
    DECLARE @Cabecera varchar(500)=REPLACE(LEFT(@Contenido,
      CHARINDEX(CHAR(10),@Contenido+CHAR(10))-1),CHAR(13),'''');
    IF @Cabecera COLLATE Latin1_General_100_BIN2<>
      ''VentaId;Fecha;Cliente;Cantidad;Precio'' COLLATE Latin1_General_100_BIN2
      THROW 51002,''Cabecera CSV incorrecta.'',1;';
  EXEC sys.sp_executesql @HeaderSql;
  DECLARE @Sql nvarchar(max)=N'BULK INSERT #Raw FROM '''+
    REPLACE(@Archivo,'''','''''')+N''' WITH (FORMAT=''CSV'', FIRSTROW=2,
    FIELDTERMINATOR='';'', ROWTERMINATOR=''0x0a'', CODEPAGE=''65001'',
    KEEPNULLS, TABLOCK, MAXERRORS=0);';
  EXEC sys.sp_executesql @Sql;
  -- Fila identifica el registro de staging, no el numero de linea del CSV.
  INSERT dbo.StagingVentas
  SELECT @RunId, ROW_NUMBER() OVER(ORDER BY (SELECT NULL)),
    VentaId,Fecha,Cliente,Cantidad,REPLACE(Precio,CHAR(13),N'') FROM #Raw;
  SET @Leidas=@@ROWCOUNT;

  SELECT s.Fila, TRY_CONVERT(int,TRIM(VentaIdRaw)) VentaId,
    TRY_CONVERT(date,TRIM(FechaRaw),23) Fecha,
    UPPER(TRIM(ClienteRaw) COLLATE Latin1_General_100_CI_AS) Cliente,
    TRY_CONVERT(int,TRIM(CantidadRaw)) Cantidad,
    TRY_CONVERT(decimal(12,2),TRIM(PrecioRaw)) Precio,
    TRIM(FechaRaw) FechaTexto, TRIM(PrecioRaw) PrecioTexto
  INTO #Tipadas FROM dbo.StagingVentas s WHERE RunId=@RunId;

  SELECT *, COUNT(*) OVER(PARTITION BY VentaId) Repeticiones INTO #Clasificadas
  FROM #Tipadas;
  SELECT *, CAST(CASE
    WHEN VentaId IS NULL OR VentaId<=0 THEN N'VentaId invalido'
    WHEN Fecha IS NULL OR CONVERT(nvarchar(10),Fecha,23)<>FechaTexto
      THEN N'Fecha invalida'
    WHEN NULLIF(Cliente,N'') IS NULL OR LEN(Cliente)>100 THEN N'Cliente invalido'
    WHEN Cantidad IS NULL OR Cantidad NOT BETWEEN 1 AND 100000
      THEN N'Cantidad invalida'
    WHEN Precio IS NULL OR Precio NOT BETWEEN 0.01 AND 1000000
      OR PrecioTexto LIKE N'%,%'
      OR PrecioTexto LIKE N'%[^0-9.]%' COLLATE Latin1_General_100_BIN2
      OR (CHARINDEX(N'.',PrecioTexto)>0 AND
          LEN(PrecioTexto)-CHARINDEX(N'.',PrecioTexto)>2)
      THEN N'Precio invalido'
    WHEN Repeticiones>1 THEN N'VentaId duplicado en el archivo'
    ELSE NULL END AS nvarchar(200)) Motivo
  INTO #Validadas FROM #Clasificadas;
  INSERT dbo.Rechazos SELECT @RunId,Fila,Motivo FROM #Validadas WHERE Motivo IS NOT NULL;
  SELECT @Aceptadas=COUNT(*) FROM #Validadas WHERE Motivo IS NULL;

  UPDATE d SET Fecha=v.Fecha,Cliente=v.Cliente,Cantidad=v.Cantidad,
    Precio=v.Precio,Importe=CAST(v.Cantidad*v.Precio AS decimal(18,2)),
    UltimoRunId=@RunId
  FROM dbo.Ventas d JOIN #Validadas v ON d.VentaId=v.VentaId
  WHERE v.Motivo IS NULL AND (d.Fecha<>v.Fecha
    OR d.Cliente COLLATE Latin1_General_100_BIN2<>v.Cliente COLLATE Latin1_General_100_BIN2
    OR d.Cantidad<>v.Cantidad OR d.Precio<>v.Precio);
  SET @Actualizadas=@@ROWCOUNT;
  INSERT dbo.Ventas
  SELECT VentaId,Fecha,Cliente,Cantidad,Precio,
    CAST(Cantidad*Precio AS decimal(18,2)),@RunId
  FROM #Validadas v WHERE Motivo IS NULL
    AND NOT EXISTS(SELECT 1 FROM dbo.Ventas d WHERE d.VentaId=v.VentaId);
  SET @Insertadas=@@ROWCOUNT;
  UPDATE dbo.Ejecuciones SET Fin=SYSUTCDATETIME(),Estado='CORRECTA',
    Leidas=@Leidas,Aceptadas=@Aceptadas,Rechazadas=@Leidas-@Aceptadas,
    Insertadas=@Insertadas,Actualizadas=@Actualizadas WHERE RunId=@RunId;
  COMMIT;
 END TRY
 BEGIN CATCH
  IF @@TRANCOUNT>0 ROLLBACK;
  UPDATE dbo.Ejecuciones SET Fin=SYSUTCDATETIME(),Estado='ERROR',
    Error=ERROR_MESSAGE() WHERE RunId=@RunId;
  THROW;
 END CATCH;
END;
GO

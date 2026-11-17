IF OBJECT_ID(N'dbo.Ejecuciones',N'U') IS NULL
CREATE TABLE dbo.Ejecuciones (
 RunId uniqueidentifier NOT NULL PRIMARY KEY,
 Inicio datetime2 NOT NULL DEFAULT SYSUTCDATETIME(), Fin datetime2 NULL,
 Archivo nvarchar(4000) NOT NULL, Estado varchar(12) NOT NULL,
 Leidas int NULL, Aceptadas int NULL, Rechazadas int NULL,
 Insertadas int NULL, Actualizadas int NULL, Error nvarchar(2048) NULL
);
IF OBJECT_ID(N'dbo.StagingVentas',N'U') IS NULL
CREATE TABLE dbo.StagingVentas (
 RunId uniqueidentifier NOT NULL, Fila int NOT NULL,
 VentaIdRaw nvarchar(100) NULL, FechaRaw nvarchar(100) NULL,
 ClienteRaw nvarchar(400) NULL, CantidadRaw nvarchar(100) NULL,
 PrecioRaw nvarchar(100) NULL,
 CONSTRAINT PK_StagingVentas PRIMARY KEY(RunId,Fila)
);
IF OBJECT_ID(N'dbo.Rechazos',N'U') IS NULL
CREATE TABLE dbo.Rechazos (
 RunId uniqueidentifier NOT NULL, Fila int NOT NULL, Motivo nvarchar(200) NOT NULL,
 CONSTRAINT PK_Rechazos PRIMARY KEY(RunId,Fila),
 CONSTRAINT FK_Rechazos_Staging FOREIGN KEY(RunId,Fila)
 REFERENCES dbo.StagingVentas(RunId,Fila)
);
IF OBJECT_ID(N'dbo.Ventas',N'U') IS NULL
CREATE TABLE dbo.Ventas (
 VentaId int NOT NULL PRIMARY KEY, Fecha date NOT NULL,
 Cliente nvarchar(100) NOT NULL, Cantidad int NOT NULL,
 Precio decimal(12,2) NOT NULL, Importe decimal(18,2) NOT NULL,
 UltimoRunId uniqueidentifier NOT NULL,
 CONSTRAINT CK_Ventas_Cantidad CHECK(Cantidad BETWEEN 1 AND 100000),
 CONSTRAINT CK_Ventas_Precio CHECK(Precio BETWEEN 0.01 AND 1000000)
);
GO

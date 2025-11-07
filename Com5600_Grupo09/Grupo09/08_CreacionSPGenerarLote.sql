/**********************************************************
 * Bases de Datos Aplicada - Comisión 5600
 * GRUPO 09
 *
 * Archivo: 08_CreacionSPGenerarLote.sql
 * Enunciado cumplimentado: Creación SP para generar lotes
 * de forma aleatoria
 *
 * Integrantes:
 * - Ludmila Daiana Ibarra Sánchez DNI 42537300
 * - Gianluca Ferreyra DNI 46026937
 * - Rodrigo Ezequiel Maranzana DNI 41853030
 *********************************************************/
 
USE Com5600G09;
GO

 CREATE OR ALTER PROCEDURE importar.p_GenerarLotePagos
(
    @Cantidad INT = 5000,
    @FechaInicio DATE = '2025-04-01',
    @DiasRango INT = 91,
    @ImporteMin DECIMAL(12,2) = 500.00,
    @ImporteMax DECIMAL(12,2) = 5000.00,
    @Probabilidad FLOAT
)
AS
BEGIN
    SET NOCOUNT ON;
    PRINT '============== INICIO DE importar.p_GenerarLotePagos ==============';

    DROP TABLE IF EXISTS #ClaveUniformeID;
    SELECT 
        NroClaveUniformeID 
    INTO #ClaveUniformeID
    FROM 
        persona.CuentaBancaria;

    IF NOT EXISTS (SELECT 1 FROM #ClaveUniformeID)
    BEGIN
        PRINT('La tabla persona.CuentaBancaria no tiene registros. No se pueden generar pagos.');
        RETURN;
    END

    DECLARE @i INT = 1;

    BEGIN TRANSACTION;
    WHILE @i <= @Cantidad
    BEGIN
        
        DECLARE @NroClaveUniformeID CHAR(22) = (SELECT TOP 1 NroClaveUniformeID FROM #ClaveUniformeID ORDER BY NEWID());
        
        DECLARE @Importe DECIMAL(12,2) = @ImporteMin + RAND() * (@ImporteMax - @ImporteMin);
        
        DECLARE @FechaAleatoria DATE = DATEADD(DAY, (RAND() * @DiasRango), @FechaInicio);

        DECLARE @Concepto CHAR(20);

        IF RAND() < @Probabilidad
            SET @Concepto = 'EXTRAORDINARIO';
        ELSE
            SET @Concepto = 'ORDINARIO';

        INSERT INTO contable.Pago 
            (Fecha, NroClaveUniformeID, Concepto, Importe)
        VALUES 
            (@FechaAleatoria, @NroClaveUniformeID, @Concepto, @Importe);

        SET @i += 1;
    END
    COMMIT TRANSACTION;

    PRINT '============== FIN DE importar.p_GenerarLotePagos ==============';
END
GO

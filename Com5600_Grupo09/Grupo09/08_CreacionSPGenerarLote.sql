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


----------------------------------------------------------------------------------------------------------------------------------
	/* STORED PROCEDURE importar.p_GenerarLotePagos */
----------------------------------------------------------------------------------------------------------------------------------


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


----------------------------------------------------------------------------------------------------------------------------------
	/* STORED PROCEDURE importar.p_GenerarGastosExtraordinariosDesdePagos */
----------------------------------------------------------------------------------------------------------------------------------


CREATE OR ALTER PROCEDURE importar.p_GenerarGastosExtraordinariosDesdePagos
AS
BEGIN
    SET NOCOUNT ON;

    PRINT '============== INICIO DE importar.p_GenerarGastosExtraordinariosDesdePagos ==============';

    DROP TABLE IF EXISTS #GastosSumados;

    WITH PagosExtraordinarios AS (
        SELECT 
            UnidadFuncional.ConsorcioID,
            DATEFROMPARTS(YEAR(Pago.Fecha), MONTH(Pago.Fecha), 1) AS Periodo, -- generamos el periodo para cada pago segun su fecha (primer dia del mes)
            Pago.Importe
        FROM contable.Pago AS Pago
        JOIN persona.CuentaBancaria AS CuentaBancaria 
            ON Pago.NroClaveUniformeID = CuentaBancaria.NroClaveUniformeID
        JOIN infraestructura.UnidadFuncional AS UnidadFuncional
            ON (CuentaBancaria.PersonaID = UnidadFuncional.PropietarioID OR CuentaBancaria.PersonaID = UnidadFuncional.InquilinoID)
        WHERE 
            Pago.Concepto = 'EXTRAORDINARIO'
    )
    SELECT 
        ConsorcioID,
        Periodo,
        SUM(Importe) AS ImporteTotal
    INTO #GastosSumados
    FROM PagosExtraordinarios
    GROUP BY ConsorcioID, Periodo;


    UPDATE GastoExtraordinario
    SET 
        GastoExtraordinario.Importe = #GastosSumados.ImporteTotal,
        GastoExtraordinario.CuotasTotales = NULL,
        GastoExtraordinario.CuotaActual = NULL
    FROM contable.GastoExtraordinario AS GastoExtraordinario
    JOIN #GastosSumados
        ON GastoExtraordinario.ConsorcioID = #GastosSumados.ConsorcioID
        AND GastoExtraordinario.Periodo = #GastosSumados.Periodo;

    INSERT INTO contable.GastoExtraordinario
        (ConsorcioID, Periodo, Tipo, ModalidadPago, CuotasTotales, CuotaActual, Importe)
    SELECT
        #GastosSumados.ConsorcioID,
        #GastosSumados.Periodo,
        'REPARACION',
        'TOTAL',
        NULL,
        NULL,
        #GastosSumados.ImporteTotal
    FROM #GastosSumados
    WHERE NOT EXISTS (
        SELECT 1
        FROM contable.GastoExtraordinario AS GastoExtraordinario
        WHERE GastoExtraordinario.ConsorcioID = #GastosSumados.ConsorcioID
            AND GastoExtraordinario.Periodo = #GastosSumados.Periodo
            AND GastoExtraordinario.Tipo = 'REPARACION'
    );

    PRINT '============== FIN DE importar.p_GenerarGastosExtraordinariosDesdePagos ==============';
END
GO


----------------------------------------------------------------------------------------------------------------------------------
	/* STORED PROCEDURE importar.p_GenerarGastosOrdinariosDesdePagos */
----------------------------------------------------------------------------------------------------------------------------------


CREATE OR ALTER PROCEDURE importar.p_GenerarGastosOrdinariosDesdePagos
AS
BEGIN
    SET NOCOUNT ON;

    PRINT '============== INICIO DE importar.p_GenerarGastosOrdinariosDesdePagos ==============';

    DECLARE @FactorMinimo DECIMAL(5,2) = 0.98; -- 98%
    DECLARE @FactorMaximo DECIMAL(5,2) = 1.02; -- 102%

    DROP TABLE IF EXISTS #Totales;
    DROP TABLE IF EXISTS #Ajustes;

    WITH PagosSumados AS (
        SELECT 
            UF.ConsorcioID,
            DATEFROMPARTS(YEAR(Pago.Fecha), MONTH(Pago.Fecha), 1) AS Periodo,
            SUM(Pago.Importe) AS TotalPagado
        FROM contable.Pago AS Pago
        JOIN persona.CuentaBancaria AS CuentaBancaria 
            ON Pago.NroClaveUniformeID = CuentaBancaria.NroClaveUniformeID
        JOIN infraestructura.UnidadFuncional AS UF
            ON (CuentaBancaria.PersonaID = UF.PropietarioID OR CuentaBancaria.PersonaID = UF.InquilinoID)
        GROUP BY 
            UF.ConsorcioID, DATEFROMPARTS(YEAR(Pago.Fecha), MONTH(Pago.Fecha), 1)
    ),
    GastosActualesCTE AS (
        SELECT ConsorcioID, Periodo, SUM(Importe) AS TotalGastadoActual
        FROM (
            SELECT ConsorcioID, Periodo, Importe FROM contable.GastoOrdinario
            UNION ALL
            SELECT ConsorcioID, Periodo, Importe FROM contable.GastoExtraordinario
        ) AS GastosTotales
        GROUP BY ConsorcioID, Periodo
    )

    SELECT
        PagosSumados.ConsorcioID,
        PagosSumados.Periodo,
        PagosSumados.TotalPagado,
        ISNULL(GastosActualesCTE.TotalGastadoActual, 0) AS TotalGastadoActual
    INTO #Totales
    FROM PagosSumados AS PagosSumados
    LEFT JOIN GastosActualesCTE
        ON PagosSumados.ConsorcioID = GastosActualesCTE.ConsorcioID AND PagosSumados.Periodo = GastosActualesCTE.Periodo;

    SELECT
        ConsorcioID,
        Periodo,
        TotalPagado,
        TotalGastadoActual,
    CASE 
        WHEN TotalGastadoActual < (TotalPagado * @FactorMinimo) -- cuando haya menos gasto que pagos (considerando un factor minimo para variabilidad)
        THEN (TotalPagado * (@FactorMinimo + (RAND(CHECKSUM(NEWID())) * (@FactorMaximo - @FactorMinimo)))) - TotalGastadoActual
        ELSE 0  -- compensamos los pagos de forma aleatoria elevando el gasto entre un 90% y un 102% (para generar unidades con deuda y sin ella)
    END AS ImporteAjuste
    INTO #Ajustes
    FROM #Totales;

    UPDATE GastoOrdinario
    SET 
        GastoOrdinario.Importe = GastoOrdinario.Importe + #Ajustes.ImporteAjuste
    FROM contable.GastoOrdinario AS GastoOrdinario
    JOIN #Ajustes
        ON GastoOrdinario.ConsorcioID = #Ajustes.ConsorcioID
        AND GastoOrdinario.Periodo = #Ajustes.Periodo
    WHERE 
        GastoOrdinario.Categoria = 'GASTOS GENERALES'
        AND #Ajustes.ImporteAjuste > 0;
        

    INSERT INTO contable.GastoOrdinario (ConsorcioID, Periodo, Categoria, Importe)
    SELECT
        #Ajustes.ConsorcioID,
        #Ajustes.Periodo,
        'GASTOS GENERALES', -- Utilizamos la categoria generica
        #Ajustes.ImporteAjuste
    FROM #Ajustes
    WHERE
        #Ajustes.ImporteAjuste > 0
        AND NOT EXISTS (
            SELECT 1
            FROM contable.GastoOrdinario AS GastoOrdinario
            WHERE GastoOrdinario.ConsorcioID = #Ajustes.ConsorcioID
                AND GastoOrdinario.Periodo = #Ajustes.Periodo
                AND GastoOrdinario.Categoria = 'GASTOS GENERALES'
        );
        
    PRINT '============== FIN DE importar.p_GenerarGastosOrdinariosDesdePagos ==============';
END
GO
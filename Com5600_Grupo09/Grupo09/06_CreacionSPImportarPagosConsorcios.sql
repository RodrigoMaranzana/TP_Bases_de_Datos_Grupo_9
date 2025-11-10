/**********************************************************
 * Bases de Datos Aplicada - Comisión 5600
 * GRUPO 09
 *
 * Archivo: 06_CreacionSPImportarPagosConsorcios.sql
 * Enunciado cumplimentado: Creación del SP para importar 
 * el maestro pagos_consorcios.csv
 *
 * Integrantes:
 * - Ludmila Daiana Ibarra Sánchez DNI 42537300
 * - Gianluca Ferreyra DNI 46026937
 * - Rodrigo Ezequiel Maranzana DNI 41853030
 *********************************************************/


USE Com5600G09;
GO

CREATE OR ALTER PROCEDURE importar.p_ImportarPagosConsorcios
    @RutaArchivo VARCHAR(260)
AS
BEGIN
    SET NOCOUNT ON;

    PRINT CHAR(10) + '============== INCIO DE p_ImportarPagosConsorcios ==============';

    DROP TABLE IF EXISTS #PagosCSVTemp;
    DROP TABLE IF EXISTS #PagosLimpio;

    CREATE TABLE #PagosCSVTemp ( --columnas del archivo
        IDDePago VARCHAR(255) COLLATE Latin1_General_CI_AI,
        Fecha  VARCHAR(255) COLLATE Latin1_General_CI_AI,
        CvuCbu VARCHAR(255) COLLATE Latin1_General_CI_AI,
        Valor VARCHAR(255) COLLATE Latin1_General_CI_AI
    );

    BEGIN TRY

        ----------------------------------------------------------------------------------------------------------------------------------
        /* BLOQUE GENERAL */
        ----------------------------------------------------------------------------------------------------------------------------------

        DECLARE @Proceso VARCHAR(128) = 'importar.p_ImportarPagosConsorcios';

        DECLARE @BulkInsert NVARCHAR(MAX);

        -- variables para reporte XML
        DECLARE @LeidosDeArchivo INT;
        DECLARE @Insertados INT;
        DECLARE @Actualizados INT;
        DECLARE @DuplicadosEnArchivo INT;
        DECLARE @DuplicadosEnTabla INT;
        DECLARE @Corruptos INT;
        DECLARE @ReporteXML XML;
        DECLARE @LogID INT;

        SET @ReporteXML = (
            SELECT @RutaArchivo AS 'NombreArchivo' 
            FOR XML PATH('ReporteXMLRegistros')
        );
        
        ----------------------------------------------------------------------------------------------------------------------------------
        /* IMPORTACION ARCHIVO CSV */
        ----------------------------------------------------------------------------------------------------------------------------------

        PRINT CHAR(10) + '>>> Iniciando el proceso para el archivo';

        SET @BulkInsert = N'
            BULK INSERT #PagosCSVTemp
            FROM ''' + @RutaArchivo + '''
            WITH (
                FIELDTERMINATOR = '','',
                ROWTERMINATOR = ''0x0d0a'',     -- según notepad es Windows CR LF, este sería el salto de línea ''\r\n''
                FIRSTROW = 2,                   -- omitimos el header 
                CODEPAGE = ''65001''            -- según notepad el encoding es UTF-8 
            );';
        
        EXEC sp_executesql @BulkInsert;
        SET @LeidosDeArchivo = @@ROWCOUNT;

        ----------------------------------------------------------------------------------------------------------------------------------
        /* NORMALIZACION Y FILTRADO */
        ----------------------------------------------------------------------------------------------------------------------------------

        WITH CTE AS ( -- limpio los registros de la tabla y doy formato
            SELECT
                TRY_CAST(general.f_RemoverBlancos(IDDePago) AS INT) AS PagoID,
                general.f_NormalizarFecha_DDMMYYYY(Fecha) AS Fecha,
                CASE WHEN general.f_RemoverBlancos(CvuCbu) LIKE '%[^0-9]%' THEN NULL ELSE CAST(general.f_RemoverBlancos(CvuCbu) AS CHAR(22)) END AS NroClaveUniforme,
                general.f_NormalizarImporte(Valor) AS Importe
            FROM #PagosCSVTemp
        )
        SELECT
            CTE.PagoID,
            CTE.Fecha,
            CTE.NroClaveUniforme,
            CTE.Importe
        INTO #PagosLimpio
        FROM CTE
        WHERE
            NULLIF(CTE.NroClaveUniforme, '') IS NOT NULL AND
            NULLIF(CTE.Fecha, '') IS NOT NULL AND
            Importe > 0;

         SET @Corruptos = @LeidosDeArchivo - @@ROWCOUNT;

        ----------------------------------------------------------------------------------------------------------------------------------
        /* UPDATE DE FILAS DE LA TABLA FISICA infraestructura.UnidadFuncional */
        ----------------------------------------------------------------------------------------------------------------------------------
        
        /** No hay nada que actualizar en pagos **/

        ----------------------------------------------------------------------------------------------------------------------------------
        /* INSERT DE FILAS NUEVAS EN LA TABLA FISICA infraestructura.UnidadFuncional */
        ----------------------------------------------------------------------------------------------------------------------------------
  
        INSERT INTO contable.Pago (
            Fecha,
            NroClaveUniformeID,
            Concepto,
            Importe
        )
        SELECT
            Limpio.Fecha,
            Limpio.NroClaveUniforme,
            'ORDINARIO',
            Limpio.Importe
        FROM #PagosLimpio AS Limpio
        WHERE NOT EXISTS (
            SELECT 1
            FROM contable.Pago AS Pago
            WHERE Pago.PagoID = Limpio.PagoID -- siemrpe que no se repita el id del pago, lo cargamos (puede haber dos pagos iguales, salvo por ese id)
        );

        SET @Insertados = @@ROWCOUNT;
        SET @DuplicadosEnTabla = @LeidosDeArchivo - @Insertados - @Corruptos;

        EXEC general.p_RegistrarLog 
            @Proceso = @Proceso,
            @Tipo = 'INFO',
            @Mensaje = 'Proceso de importacion de pagos completado',
            @ReporteXML = @ReporteXML;

    END TRY
    BEGIN CATCH
      
        EXEC general.p_RegistrarLog 
            @Proceso = @Proceso,
            @Tipo = 'ERROR',
            @Mensaje = 'Fallo la importacion';
    
    END CATCH

    PRINT CHAR(10) + '============== FIN DE p_ImportarPagosConsorcios ==============';
END
GO    
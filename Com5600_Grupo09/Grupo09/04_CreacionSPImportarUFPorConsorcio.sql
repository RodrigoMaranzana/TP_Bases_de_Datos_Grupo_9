/**********************************************************
 * Bases de Datos Aplicada - Comisión 5600
 * GRUPO 09
 *
 * Archivo: 04_CreacionSPImportarUFPorConsorcio.sql
 * Enunciado cumplimentado: Creación del SP para importar 
 * el maestro UF por consorcio.txt
 *
 * Integrantes:
 * - Ludmila Daiana Ibarra Sánchez DNI 42537300
 * - Gianluca Ferreyra DNI 46026937
 * - Rodrigo Ezequiel Maranzana DNI 41853030
 *********************************************************/


USE Com5600G09;
GO

CREATE OR ALTER PROCEDURE importar.p_ImportarUnidadFuncional
    @RutaArchivo VARCHAR(260)
AS
BEGIN
    SET NOCOUNT ON;

    PRINT CHAR(10) + '============== INCIO DE p_ImportarUnidadFuncional ==============';

    DROP TABLE IF EXISTS #UnidadFuncionalCSVTemp;
    DROP TABLE IF EXISTS #UnidadFuncionalLimpio;

    CREATE TABLE #UnidadFuncionalCSVTemp ( --columnas del archivo
        NombreDelConsorcio VARCHAR(255) COLLATE Latin1_General_CI_AI,
        NroUnidadFuncional  VARCHAR(255) COLLATE Latin1_General_CI_AI,
        Piso VARCHAR(255) COLLATE Latin1_General_CI_AI,
        Departamento VARCHAR(255) COLLATE Latin1_General_CI_AI,
        Coeficiente VARCHAR(255) COLLATE Latin1_General_CI_AI,
        M2UnidadFuncional VARCHAR(255) COLLATE Latin1_General_CI_AI,
        Bauleras VARCHAR(255) COLLATE Latin1_General_CI_AI,
        Cochera VARCHAR(255) COLLATE Latin1_General_CI_AI,
        M2Baulera VARCHAR(255) COLLATE Latin1_General_CI_AI,
        M2Cochera VARCHAR(255) COLLATE Latin1_General_CI_AI,
    );

    BEGIN TRY

        ----------------------------------------------------------------------------------------------------------------------------------
        /* BLOQUE GENERAL */
        ----------------------------------------------------------------------------------------------------------------------------------

        DECLARE @Proceso VARCHAR(128) = 'importar.p_ImportarUnidadFuncional';

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
            BULK INSERT #UnidadFuncionalCSVTemp
            FROM ''' + @RutaArchivo + '''
            WITH (
                FIELDTERMINATOR = ''\t'',
                ROWTERMINATOR = ''0x0d0a'',     -- según notepad es Windows CR LF, este sería el salto de línea ''\r\n''
                FIRSTROW = 2,                   -- omitimos el header 
                CODEPAGE = ''65001''            -- según notepad el encoding es UTF-8 
            );';
        
        EXEC sp_executesql @BulkInsert;
        SET @LeidosDeArchivo = @@ROWCOUNT;

        ALTER TABLE #UnidadFuncionalCSVTemp ADD RegistroID INT IDENTITY(1,1);

        ----------------------------------------------------------------------------------------------------------------------------------
        /* NORMALIZACION Y FILTRADO */
        ----------------------------------------------------------------------------------------------------------------------------------

        WITH CTE AS ( -- limpio los registros de la tabla y doy formato
            SELECT
                RegistroID,
                CAST(UPPER(LTRIM(RTRIM(NombreDelConsorcio))) AS VARCHAR(255)) AS NombreDelConsorcio,
                TRY_CAST(NroUnidadFuncional AS INT) AS NroUnidadFuncionalID,
                CAST(UPPER(LTRIM(RTRIM(Piso))) AS CHAR(2)) AS Piso,
                CAST(UPPER(LTRIM(RTRIM(Departamento))) AS CHAR(1)) AS Departamento,
                TRY_CAST(REPLACE(Coeficiente, ',', '.') AS DECIMAL(3,1)) AS Coeficiente,
                TRY_CAST(M2UnidadFuncional AS DECIMAL(6,2)) AS Superficie,
                LTRIM(RTRIM(Bauleras)) AS Bauleras, 
                LTRIM(RTRIM(Cochera)) AS Cochera,
                TRY_CAST(M2Baulera AS DECIMAL(6,2)) AS SuperficieBaulera,
                TRY_CAST(M2Cochera AS DECIMAL(6,2)) AS SuperficieCochera
            FROM #UnidadFuncionalCSVTemp
        )
        SELECT *, -- con ROW_NUMBER cuento la cantidad de veces que se repiten registros con mismo NombreDelConsorcio, NroUnidadFuncional, Piso y Departamento
        ROW_NUMBER() OVER (PARTITION BY NombreDelConsorcio, NroUnidadFuncionalID, Piso, Departamento ORDER BY RegistroID) AS CantApariciones 
        INTO #UnidadFuncionalLimpio
        FROM CTE
        WHERE
            CTE.NroUnidadFuncionalID IS NOT NULL AND  
            NULLIF(CTE.NombreDelConsorcio, '') IS NOT NULL AND
            NULLIF(CTE.Piso, '') IS NOT NULL AND
            NULLIF(CTE.Departamento, '') IS NOT NULL AND
            CTE.Coeficiente > 0 AND
            CTE.Superficie > 0 AND
            ((CTE.Bauleras = 'NO' AND CTE.SuperficieBaulera = 0) OR (CTE.Bauleras = 'SI' AND CTE.SuperficieBaulera > 0)) AND
            ((CTE.Cochera = 'NO' AND CTE.SuperficieCochera = 0) OR (CTE.Cochera = 'SI' AND CTE.SuperficieCochera > 0));
            -- en las dos anteriores comprobamos que sea consistente la afirmacion/negacion con los valores entregados (doble confirmacion)

        SET @Corruptos = @LeidosDeArchivo - @@ROWCOUNT;
        SET @DuplicadosEnArchivo = (SELECT COUNT(*) FROM #UnidadFuncionalLimpio WHERE CantApariciones > 1);

        ----------------------------------------------------------------------------------------------------------------------------------
        /* UPDATE DE FILAS DE LA TABLA FISICA infraestructura.UnidadFuncional */
        ----------------------------------------------------------------------------------------------------------------------------------
        
        UPDATE UnidadFuncional
        SET -- estos son los campos que considero se deberian poder actualizar
            UnidadFuncional.Coeficiente = Limpio.Coeficiente,
            UnidadFuncional.Superficie = Limpio.Superficie,
            UnidadFuncional.SuperficieBaulera = Limpio.SuperficieBaulera,
            UnidadFuncional.SuperficieCochera = Limpio.SuperficieCochera
        FROM #UnidadFuncionalLimpio AS Limpio
        JOIN infraestructura.Consorcio AS Consorcio 
            ON Limpio.NombreDelConsorcio = Consorcio.NombreDelConsorcio
        JOIN infraestructura.UnidadFuncional AS UnidadFuncional
            ON UnidadFuncional.ConsorcioID = Consorcio.ConsorcioID
            AND UnidadFuncional.NroUnidadFuncionalID = Limpio.NroUnidadFuncionalID
        WHERE
            UnidadFuncional.Coeficiente <> Limpio.Coeficiente OR
            UnidadFuncional.Superficie <> Limpio.Superficie OR
            UnidadFuncional.SuperficieBaulera <> Limpio.SuperficieBaulera OR
            UnidadFuncional.SuperficieCochera <> Limpio.SuperficieCochera;
        SET @Actualizados = @@ROWCOUNT;

        ----------------------------------------------------------------------------------------------------------------------------------
        /* INSERT DE FILAS NUEVAS EN LA TABLA FISICA infraestructura.UnidadFuncional */
        ----------------------------------------------------------------------------------------------------------------------------------
        

        INSERT INTO infraestructura.UnidadFuncional (
            NroUnidadFuncionalID,
            ConsorcioID,
            PropietarioID,
            Piso,
            Departamento,
            Superficie,
            SuperficieBaulera,
            SuperficieCochera,
            Coeficiente)
        SELECT
            Limpio.NroUnidadFuncionalID,
            Consorcio.ConsorcioID,
            1, --corresponde al propietario indeterminado
            Limpio.Piso,
            Limpio.Departamento,
            Limpio.Superficie,
            Limpio.SuperficieBaulera,
            Limpio.SuperficieCochera,
            Limpio.Coeficiente
        FROM #UnidadFuncionalLimpio AS Limpio
        JOIN infraestructura.Consorcio AS Consorcio
            ON Limpio.NombreDelConsorcio = Consorcio.NombreDelConsorcio
        WHERE
            Limpio.CantApariciones = 1 AND-- filtra repetidos en el archivo (mejora la eficiencia al evitar el select)
            NOT EXISTS( -- filtra repetidos en la tabla fisica
                SELECT 1
                FROM infraestructura.UnidadFuncional AS UnidadFuncional
                WHERE
                    UnidadFuncional.Piso = Limpio.Piso AND
                    UnidadFuncional.Departamento = Limpio.Departamento AND
                    UnidadFuncional.NroUnidadFuncionalID = Limpio.NroUnidadFuncionalID AND
                    UnidadFuncional.ConsorcioID = Consorcio.ConsorcioID
            )  

        SET @Insertados = @@ROWCOUNT;
        SET @DuplicadosEnTabla = @LeidosDeArchivo - @Insertados - @Corruptos;

        EXEC general.p_RegistrarLog 
            @Proceso = @Proceso,
            @Tipo = 'INFO',
            @Mensaje = 'Proceso de importacion de unidades funcionales completado',
            @ReporteXML = @ReporteXML,
            @LogIDOut = @LogID OUTPUT; -- obtenemos el PK LogID generado en la insercion

        INSERT INTO general.LogRegistroRechazado (LogID, Motivo, RegistroXML)
        SELECT
            @LogID,
            CASE 
                WHEN Limpio.RegistroID IS NULL THEN 'CORRUPTO'
                ELSE 'DUPLICADO EN ARCHIVO'
            END,
            (
                SELECT 
                    Temp.NombreDelConsorcio,
                    Temp.NroUnidadFuncional,
                    Temp.Departamento,
                    Temp.Coeficiente,
                    Temp.M2UnidadFuncional,
                    Temp.Bauleras,
                    Temp.Cochera,
                    Temp.M2Baulera,
                    Temp.M2Cochera
                FOR XML PATH('FilaRechazada'), TYPE -- TYPE genera el reporte XML de forma nativa y no como un texto concatenado
            )
        FROM #UnidadFuncionalCSVTemp AS Temp
        LEFT JOIN #UnidadFuncionalLimpio AS Limpio ON Temp.RegistroID = Limpio.RegistroID
        WHERE Limpio.RegistroID IS NULL OR Limpio.CantApariciones > 1;   

    END TRY
    BEGIN CATCH
      
        EXEC general.p_RegistrarLog 
            @Proceso = @Proceso,
            @Tipo = 'ERROR',
            @Mensaje = 'Fallo la importacion';
    
    END CATCH

    PRINT CHAR(10) + '============== FIN DE p_ImportarUnidadFuncional ==============';
END
GO    
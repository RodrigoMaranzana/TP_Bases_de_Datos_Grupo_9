/**********************************************************
 * Bases de Datos Aplicada - Comisión 5600
 * GRUPO 09
 *
 * Archivo: 05_CreacionSPImportarInquilinoPropietariosUF.sql
 * Enunciado cumplimentado: Creación del SP para importar 
 * el maestro Inquilino-Propietarios-UF.csv
 *
 * Integrantes:
 * - Ludmila Daiana Ibarra Sánchez DNI 42537300
 * - Gianluca Ferreyra DNI 46026937
 * - Rodrigo Ezequiel Maranzana DNI 41853030
 *********************************************************/


USE Com5600G09;
GO

CREATE OR ALTER PROCEDURE importar.p_ImportarClaveUniformePorUF
    @RutaArchivoCSV VARCHAR(260)
AS
BEGIN
    SET NOCOUNT ON;

    PRINT CHAR(10) + '============== INCIO DE p_ImportarClaveUniformePorUF ==============';

    CREATE TABLE #ClaveUniformePorUFCSVTemp ( --columnas del archivo
        CvuCbu VARCHAR(255) COLLATE Latin1_General_CI_AI,
        NombreDelConsorcio VARCHAR(255) COLLATE Latin1_General_CI_AI,
        NroUnidadFuncional  VARCHAR(255) COLLATE Latin1_General_CI_AI,
        Piso VARCHAR(255) COLLATE Latin1_General_CI_AI,
        Departamento VARCHAR(255) COLLATE Latin1_General_CI_AI,
    );

    BEGIN TRY

        ----------------------------------------------------------------------------------------------------------------------------------
        /* BLOQUE GENERAL */
        ----------------------------------------------------------------------------------------------------------------------------------

        DECLARE @BulkInsert NVARCHAR(MAX);

        DECLARE @FilasTotalesCSV INT = 0;
        DECLARE @FilasInsertadas INT = 0;
        DECLARE @FilasCorruptas INT = 0;
        DECLARE @FilasDuplicadas INT = 0;
        
        ----------------------------------------------------------------------------------------------------------------------------------
        /* ARCHIVO CSV */
        ----------------------------------------------------------------------------------------------------------------------------------

        PRINT CHAR(10) + '>>> Iniciando el proceso para el archivo';

        SET @BulkInsert = N'
            BULK INSERT #ClaveUniformePorUFCSVTemp
            FROM ''' + @RutaArchivoCSV + '''
            WITH (
                FIELDTERMINATOR = ''|'',
                ROWTERMINATOR = ''0x0d0a'',     -- según notepad es Windows CR LF, este sería el salto de línea ''\r\n''
                FIRSTROW = 2,                   -- omitimos el header 
                CODEPAGE = ''65001''            -- según notepad el encoding es UTF-8 
            );';
        
        EXEC sp_executesql @BulkInsert;

        SELECT @FilasTotalesCSV = COUNT(*) FROM #ClaveUniformePorUFCSVTemp;
        PRINT  CHAR(10) + '>>> El archivo se cargo en #ClaveUniformePorUFCSVTemp.' + CHAR(10) + '     Filas totales: ' + CAST(@FilasTotalesCSV AS VARCHAR(10));

        ALTER TABLE #ClaveUniformePorUFCSVTemp ADD RegistroID INT IDENTITY(1,1);

        ----------------------------------------------------------------------------------------------------------------------------------
        /* NORMALIZACION Y FILTRADO */
        ----------------------------------------------------------------------------------------------------------------------------------

        WITH CTE AS ( -- limpio los registros de la tabla y doy formato
            SELECT
                RegistroID,
                CASE WHEN general.f_RemoverBlancos(CvuCbu) LIKE '%[^0-9]%' THEN NULL ELSE CAST(general.f_RemoverBlancos(CvuCbu) AS VARCHAR(22)) END AS NroClaveUniforme,
                CAST(UPPER(LTRIM(RTRIM(NombreDelConsorcio))) AS VARCHAR(255)) AS NombreDelConsorcio,
                TRY_CAST(NroUnidadFuncional AS INT) AS NroUnidadFuncional,
                CAST(LTRIM(RTRIM(Piso)) AS CHAR(2)) AS Piso,
                CAST(UPPER(LTRIM(RTRIM(Departamento))) AS CHAR(1)) AS Departamento

            FROM #ClaveUniformePorUFCSVTemp
        )
        SELECT -- especificamos los campos para que no genere ambieguedad con el join el NombreDelConsorcio
            CTE.RegistroID,
            CTE.NroClaveUniforme,
            CTE.NombreDelConsorcio,
            CTE.NroUnidadFuncional,
            CTE.Piso,
            CTE.Departamento, -- con ROW_NUMBER cuento la cantidad de veces que se repiten registros con mismo NombreDelConsorcio y NroUnidadFuncional
            ROW_NUMBER() OVER (
                PARTITION BY
                    CTE.NombreDelConsorcio,
                    CTE.NroUnidadFuncional,
                    CTE.Piso,
                    CTE.Departamento
                ORDER BY
                    CTE.RegistroID
            ) AS CantApariciones 
        INTO #ClaveUniformePorUFLimpio
        FROM CTE
        WHERE
            CTE.NroClaveUniforme IS NOT NULL AND  
            NULLIF(CTE.NombreDelConsorcio, '') IS NOT NULL AND
            NULLIF(CTE.NroUnidadFuncional, '') IS NOT NULL AND -- priemro validamos lo obvio, que nada no sean NULL
            EXISTS ( -- debe existir previamente la cuenta bancaria
                SELECT 1
                FROM persona.CuentaBancaria AS CuentaBancaria
                WHERE CuentaBancaria.NroClaveUniformeID = CTE.NroClaveUniforme
            ) AND
            EXISTS ( -- debe existir la unidad funcional en algun consorcio
                SELECT 1
                FROM infraestructura.Consorcio AS Consorcio
                JOIN infraestructura.UnidadFuncional AS UnidadFuncional 
                    ON UnidadFuncional.ConsorcioID = Consorcio.ConsorcioID
                WHERE 
                    Consorcio.NombreDelConsorcio = CTE.NombreDelConsorcio AND
                    UnidadFuncional.NroUnidadFuncionalID = CTE.NroUnidadFuncional AND
                    UnidadFuncional.Piso = CTE.Piso AND -- revisamos que coincida el piso y departamento con lo guardado en la tabla UnidadFuncional
                    UnidadFuncional.Departamento = CTE.Departamento);

        SET @FilasCorruptas = @FilasTotalesCSV - @@ROWCOUNT;

        -- informamos que un registro fue rechazado por corrupto
        SELECT Temp.*,
            CASE 
                WHEN Limpio.RegistroID IS NULL THEN 'Rechazado: Corrupto'
                ELSE 'Rechazado: Duplicado en el archivo'
            END AS Estado
        FROM #ClaveUniformePorUFCSVTemp AS Temp
        LEFT JOIN #ClaveUniformePorUFLimpio AS Limpio
            ON Temp.RegistroID = Limpio.RegistroID
        WHERE -- se muestran los que no estan en la tabla limpia o los que estan duplicados en el archivo
            Limpio.RegistroID IS NULL
            OR Limpio.CantApariciones > 1;

        ----------------------------------------------------------------------------------------------------------------------------------
        /* UPDATE DE FILAS DE LA TABLA FISICA infraestructura.UnidadFuncional */
        ----------------------------------------------------------------------------------------------------------------------------------
        
        UPDATE UnidadFuncional
        SET 
            UnidadFuncional.NroClaveUniformeID = Limpio.NroClaveUniforme
        FROM #ClaveUniformePorUFLimpio AS Limpio
        JOIN infraestructura.Consorcio AS Consorcio 
            ON Limpio.NombreDelConsorcio = Consorcio.NombreDelConsorcio -- buscamos al consorcio por su nombre
        JOIN infraestructura.UnidadFuncional AS UnidadFuncional 
            ON UnidadFuncional.ConsorcioID = Consorcio.ConsorcioID -- donde la unidad pertenezca al consorcio
            AND UnidadFuncional.NroUnidadFuncionalID = Limpio.NroUnidadFuncional
        WHERE
            UnidadFuncional.Piso = Limpio.Piso AND
            UnidadFuncional.Departamento = Limpio.Departamento AND
            ISNULL(UnidadFuncional.NroClaveUniformeID, '') <> Limpio.NroClaveUniforme; -- ISNULL() permite actualizar en caso de que la primera vez se haya insertado NULL en la tabla
        
        ----------------------------------------------------------------------------------------------------------------------------------
        /* INSERT DE FILAS NUEVAS EN LA TABLA FISICA infraestructura.UnidadFuncional */
        ----------------------------------------------------------------------------------------------------------------------------------
        /* En este caso no hay inserciones nuevas que realizar, es un archivo de solo actualizaciones de Claves Uniformes */

        SET @FilasInsertadas = @@ROWCOUNT; -- la cantidad de filas que fueron afectadas por el INSERT
        SET @FilasDuplicadas = @FilasTotalesCSV - @FilasInsertadas - @FilasCorruptas;

        EXEC general.p_RegistrarLogImportacion
            @NombreImportacion = 'infraestructura.UnidadFuncional',
            @FilasInsertadas = @FilasInsertadas,
            @FilasDuplicadas = @FilasDuplicadas,
            @FilasCorruptas = @FilasCorruptas,
            @Detalle = 'Proceso completado con normalidad.',
            @MostrarPorConsola = 1;   

    END TRY
    BEGIN CATCH
      
        EXEC general.p_RegistrarLogImportacion
            @NombreImportacion = 'infraestructura.UnidadFuncional',
            @FilasInsertadas = @FilasInsertadas,
            @FilasDuplicadas = @FilasDuplicadas,
            @FilasCorruptas = @FilasCorruptas,
            @Detalle = 'Error: No se pudo cargar el archivo CSV.',
            @MostrarPorConsola = 1;

        DECLARE @ErrorMessage NVARCHAR(4000);
        SELECT @ErrorMessage = ERROR_MESSAGE()
        PRINT @ErrorMessage;
    
    END CATCH

    PRINT CHAR(10) + '============== FIN DE p_ImportarClaveUniformePorUF ==============';

    DROP TABLE IF EXISTS #ClaveUniformePorUFCSVTemp;
    DROP TABLE IF EXISTS #ClaveUniformePorUFLimpio;
END
GO    
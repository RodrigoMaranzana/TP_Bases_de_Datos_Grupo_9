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

CREATE OR ALTER PROCEDURE importar.p_ImportarInquilinoPropietarioPorClaveUniformePorUF
    @RutaArchivo VARCHAR(260)
AS
BEGIN
    SET NOCOUNT ON;

    PRINT CHAR(10) + '============== INCIO DE p_ImportarInquilinoPropietarioPorClaveUniformePorUF ==============';

    DROP TABLE IF EXISTS #ClaveUniformePorUFCSVTemp;
    DROP TABLE IF EXISTS #ClaveUniformePorUFLimpio;

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

        DECLARE @Proceso VARCHAR(128) = 'importar.p_ImportarInquilinoPropietarioPorClaveUniformePorUF';

        DECLARE @BulkInsert NVARCHAR(MAX);

        -- variables para reporte XML
        DECLARE @LeidosDeArchivo INT;
        DECLARE @UFPropietariosActualizados INT;
        DECLARE @UFInquilinosActualizados INT;
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
            BULK INSERT #ClaveUniformePorUFCSVTemp
            FROM ''' + @RutaArchivo + '''
            WITH (
                FIELDTERMINATOR = ''|'',
                ROWTERMINATOR = ''0x0d0a'',     -- según notepad es Windows CR LF, este sería el salto de línea ''\r\n''
                FIRSTROW = 2,                   -- omitimos el header 
                CODEPAGE = ''65001''            -- según notepad el encoding es UTF-8 
            );';
        
        EXEC sp_executesql @BulkInsert;
        SET @LeidosDeArchivo = @@ROWCOUNT;

        ALTER TABLE #ClaveUniformePorUFCSVTemp ADD RegistroID INT IDENTITY(1,1);

        ----------------------------------------------------------------------------------------------------------------------------------
        /* NORMALIZACION Y FILTRADO */
        ----------------------------------------------------------------------------------------------------------------------------------

        WITH CTEFormato AS ( -- limpio los registros de la tabla y doy formato
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
            CTEFormato.RegistroID,
            CTEFormato.NroClaveUniforme,
            UnidadFuncional.ConsorcioID,
            UnidadFuncional.NroUnidadFuncionalID,
            Persona.PersonaID,
            Persona.EsPropietario,
            ROW_NUMBER() OVER (
                PARTITION BY
                    UnidadFuncional.ConsorcioID,
                    UnidadFuncional.NroUnidadFuncionalID
                ORDER BY CTEFormato.RegistroID
            ) AS CantApariciones
        INTO #ClaveUniformePorUFLimpio
        FROM CTEFormato
        JOIN infraestructura.UnidadFuncional AS UnidadFuncional
            ON CTEFormato.NroUnidadFuncional = UnidadFuncional.NroUnidadFuncionalID AND CTEFormato.Piso = UnidadFuncional.Piso AND CTEFormato.Departamento = UnidadFuncional.Departamento
        JOIN infraestructura.Consorcio AS Consorcio
            ON UnidadFuncional.ConsorcioID = Consorcio.ConsorcioID AND CTEFormato.NombreDelConsorcio = Consorcio.NombreDelConsorcio
        JOIN persona.CuentaBancaria AS CuentaBancaria
            ON CTEFormato.NroClaveUniforme = CuentaBancaria.NroClaveUniformeID
        JOIN persona.Persona AS Persona
            ON CuentaBancaria.PersonaID = Persona.PersonaID
        WHERE CTEFormato.NroClaveUniforme IS NOT NULL;

        SET @Corruptos = @LeidosDeArchivo - @@ROWCOUNT;

        ----------------------------------------------------------------------------------------------------------------------------------
        /* UPDATE DE FILAS DE LA TABLA FISICA infraestructura.UnidadFuncional */
        ----------------------------------------------------------------------------------------------------------------------------------
        
        -- con la anterior consulta vinculamos las claves uniformes con las personas titulares de esos CBU, y luego al hacer JOIN con
        -- las tablas Propietarios y Inquilinos obtenemos de que tipo es esa persona para una unidad funcional de un consorcio especifico

        UPDATE UnidadFuncional
        SET 
            UnidadFuncional.PropietarioID = Limpio.PersonaID,
            UnidadFuncional.NroClaveUniformeID = Limpio.NroClaveUniforme -- Asignamos CBU del propietario
        FROM infraestructura.UnidadFuncional AS UnidadFuncional
        JOIN #ClaveUniformePorUFLimpio AS Limpio 
            ON UnidadFuncional.ConsorcioID = Limpio.ConsorcioID AND UnidadFuncional.NroUnidadFuncionalID = Limpio.NroUnidadFuncionalID
        WHERE 
            Limpio.EsPropietario = 1;
        
        SET @UFPropietariosActualizados = @@ROWCOUNT;

        UPDATE UnidadFuncional
        SET 
            UnidadFuncional.InquilinoID = Limpio.PersonaID,
            UnidadFuncional.NroClaveUniformeID = Limpio.NroClaveUniforme
        FROM infraestructura.UnidadFuncional AS UnidadFuncional
        JOIN #ClaveUniformePorUFLimpio AS Limpio 
            ON UnidadFuncional.ConsorcioID = Limpio.ConsorcioID AND UnidadFuncional.NroUnidadFuncionalID = Limpio.NroUnidadFuncionalID
        WHERE 
            Limpio.EsPropietario = 0;

        SET @UFInquilinosActualizados = @@ROWCOUNT;

        ----------------------------------------------------------------------------------------------------------------------------------
        /* INSERT DE FILAS NUEVAS EN LA TABLA FISICA infraestructura.UnidadFuncional */
        ----------------------------------------------------------------------------------------------------------------------------------
        
        /* En este caso no hay inserciones nuevas que realizar, es un archivo de solo actualizaciones de Claves Uniformes */

        ----------------------------------------------------------------------------------------------------------------------------------
        /* REPORTE Y LOG persona.Persona, persona.Inquilino, persona.Propietario */
        ----------------------------------------------------------------------------------------------------------------------------------
    
        SET @ReporteXML = (
            SELECT 
                @LeidosDeArchivo AS 'LeidosArchivo',
                @UFPropietariosActualizados AS 'PropietariosActualizados',
                @UFInquilinosActualizados AS 'InquilinosActualizados',
                @Corruptos AS 'Corruptos'
            FOR XML PATH('ReporteXMLRegistros')
        );

        EXEC general.p_RegistrarLog 
            @Proceso = @Proceso,
            @Tipo = 'INFO',
            @Mensaje = 'Proceso de actualizacion de propietarios e inquilinos en las unidades funcionales completado',
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
                    Temp.CvuCbu,
                    Temp.NombreDelConsorcio,
                    Temp.NroUnidadFuncional,
                    Temp.Piso,
                    Temp.Departamento
                FOR XML PATH('FilaRechazada'), TYPE -- TYPE genera el reporte XML de forma nativa y no como un texto concatenado
            )
        FROM #ClaveUniformePorUFCSVTemp AS Temp
        LEFT JOIN #ClaveUniformePorUFLimpio AS Limpio ON Temp.RegistroID = Limpio.RegistroID
        WHERE Limpio.RegistroID IS NULL OR Limpio.CantApariciones > 1;

    END TRY
    BEGIN CATCH
      
        EXEC general.p_RegistrarLog 
            @Proceso = @Proceso,
            @Tipo = 'ERROR',
            @Mensaje = 'Fallo la importacion';
    
    END CATCH

    PRINT CHAR(10) + '============== FIN DE p_ImportarInquilinoPropietarioPorClaveUniformePorUF ==============';
END
GO    
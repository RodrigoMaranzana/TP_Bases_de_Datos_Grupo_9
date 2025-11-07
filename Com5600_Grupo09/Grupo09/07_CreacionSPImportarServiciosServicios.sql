/**********************************************************
 * Bases de Datos Aplicada - Comisión 5600
 * GRUPO 09
 *
 * Archivo: 07_CreacionSPImportarServiciosServicios.sql
 * Enunciado cumplimentado: Creación del SP para importar 
 * el maestro Servicios.Servicios.json
 *
 * Integrantes:
 * - Ludmila Daiana Ibarra Sánchez DNI 42537300
 * - Gianluca Ferreyra DNI 46026937
 * - Rodrigo Ezequiel Maranzana DNI 41853030
 *********************************************************/

USE Com5600G09;
GO


CREATE OR ALTER PROCEDURE importar.p_ImportarGastosOrdinariosJSON
    @RutaArchivo VARCHAR(260)
AS
BEGIN
    SET NOCOUNT ON;
    PRINT CHAR(10) + '============== INCIO DE p_ImportarGastosOrdinariosJSON ==============';

    DROP TABLE IF EXISTS #GastosJSONTemp;
    CREATE TABLE #GastosJSONTemp (
        ConsorcioID INT,
        Periodo DATE,
        Categoria VARCHAR(32) COLLATE Latin1_General_CI_AI,
        Importe DECIMAL(12,2)
    );

    DECLARE @Proceso VARCHAR(128) = 'importar.p_ImportarGastosOrdinariosJSON';
    DECLARE @LogID INT;
    DECLARE @ReporteXML XML;
    DECLARE @LeidosDeArchivo INT;
    DECLARE @Insertados INT;
    DECLARE @DuplicadosEnTabla INT;
    DECLARE @Corruptos INT;
    DECLARE @Anio INT = 2025; -- anio para el importe (el archivo no indica anio, solo mes)
    
    SET @LeidosDeArchivo = 0;
    SET @Insertados = 0;
    SET @DuplicadosEnTabla = 0;
    SET @Corruptos = 0;

    DECLARE @JsonDatos NVARCHAR(MAX);
    DECLARE @OpenrowsetJson NVARCHAR(MAX);

    --- forma de 
    SET @OpenrowsetJson = N'
        SELECT @JsonDatosSalida = BulkColumn
        FROM OPENROWSET(
            BULK ''' + @RutaArchivo + ''',
            SINGLE_CLOB
        ) AS ArchivoJson;';

    BEGIN TRY

        EXEC sp_executesql @OpenrowsetJson, N'@JsonDatosSalida NVARCHAR(MAX) OUTPUT', @JsonDatosSalida = @JsonDatos OUTPUT;

        --- REVISAR
        IF @JsonDatos IS NULL
        BEGIN
            PRINT('El archivo JSON no se pudo leer');
            RETURN;
        END

        SELECT -- seleccionamos lo que es de nuestro interes
            NombreDelConsorcio,
            Mes,
            BANCARIOS,
            LIMPIEZA,
            ADMINISTRACION,
            SEGUROS,
            GASTOS_GENERALES,
            SERVICIOS_PUBLICOS_Agua,
            SERVICIOS_PUBLICOS_Luz
        INTO #JsonTemp
        FROM OPENJSON(@JsonDatos, '$') --vinculamos cada clave del Json
        WITH (
            NombreDelConsorcio VARCHAR(255) '$."Nombre del consorcio"',
            Mes VARCHAR(20) '$.Mes',
            BANCARIOS VARCHAR(100) '$.BANCARIOS',
            LIMPIEZA VARCHAR(100) '$.LIMPIEZA',
            ADMINISTRACION VARCHAR(100) '$.ADMINISTRACION',
            SEGUROS VARCHAR(100) '$.SEGUROS',
            GASTOS_GENERALES VARCHAR(100) '$."GASTOS GENERALES"',
            SERVICIOS_PUBLICOS_Agua VARCHAR(100) '$."SERVICIOS PUBLICOS-Agua"',
            SERVICIOS_PUBLICOS_Luz VARCHAR(100) '$."SERVICIOS PUBLICOS-Luz"'
        );

        WITH JsonNoPivot AS (
            SELECT 
                Temp.NombreDelConsorcio,
                TRY_CAST(
                    CAST(@Anio AS VARCHAR(4)) + '-' + --concatenamos el anio el mes y el dia primero con guiones para castearlo como DATE
                    CASE LTRIM(RTRIM(Temp.Mes)) -- convertimos el texto del mes a su numero
                        WHEN 'enero' THEN '01'
                        WHEN 'febrero' THEN '02'
                        WHEN 'marzo' THEN '03'
                        WHEN 'abril' THEN '04'
                        WHEN 'mayo' THEN '05'
                        WHEN 'junio' THEN '06'
                        WHEN 'julio' THEN '07'
                        WHEN 'agosto' THEN '08'
                        WHEN 'septiembre' THEN '09'
                        WHEN 'octubre' THEN '10'
                        WHEN 'noviembre' THEN '11'
                        WHEN 'diciembre' THEN '12'
                    END + '-01' -- genera la fecha al dia primero
                AS DATE) AS Periodo,
                CASE -- traducimos las categorias para que coincidan con los de los proveedores
                    WHEN ValoresDespivotados.Categoria = 'BANCARIOS' THEN 'GASTOS BANCARIOS'
                    WHEN ValoresDespivotados.Categoria = 'LIMPIEZA' THEN 'GASTOS DE LIMPIEZA'
                    WHEN ValoresDespivotados.Categoria = 'ADMINISTRACION' THEN 'GASTOS DE ADMINISTRACION'
                    WHEN ValoresDespivotados.Categoria = 'GASTOS GENERALES' THEN 'GASTOS GENERALES'
                    WHEN ValoresDespivotados.Categoria = 'SEGUROS' THEN 'SEGUROS'
                    WHEN ValoresDespivotados.Categoria IN ('SERVICIOS PUBLICOS-Agua', 'SERVICIOS PUBLICOS-Luz') THEN 'SERVICIOS PUBLICOS'
                END AS Categoria,
				    TRY_CAST( 
                    CASE -- segun la posicion de la ',' y '.' realizamos los reemplazos correctos
                    WHEN CHARINDEX(',', ValoresDespivotados.ImporteTexto) > 0 AND
                    CHARINDEX('.', ValoresDespivotados.ImporteTexto) > CHARINDEX(',', ValoresDespivotados.ImporteTexto)
                        THEN REPLACE(ValoresDespivotados.ImporteTexto, ',', '') -- 22,648.59
                    WHEN CHARINDEX('.', ValoresDespivotados.ImporteTexto) > 0 AND
                    CHARINDEX(',', ValoresDespivotados.ImporteTexto) > CHARINDEX('.', ValoresDespivotados.ImporteTexto)
                        THEN REPLACE(REPLACE(ValoresDespivotados.ImporteTexto, '.', ''), ',', '.') -- 37.730,00
                    WHEN ValoresDespivotados.ImporteTexto LIKE '%,%' AND
                    ValoresDespivotados.ImporteTexto NOT LIKE '%.%'
                        THEN REPLACE(ValoresDespivotados.ImporteTexto, ',', '') -- 200,000,00
                    WHEN ValoresDespivotados.ImporteTexto LIKE '%,%' AND
                    ValoresDespivotados.ImporteTexto NOT LIKE '%.%'
                        THEN REPLACE(ValoresDespivotados.ImporteTexto, ',', '.') -- 127,00
                    ELSE ValoresDespivotados.ImporteTexto -- 127.00
                END AS DECIMAL(12,2)) AS Importe
            FROM #JsonTemp AS Temp 
            CROSS APPLY ( -- despivoteamos
                VALUES
                    ('BANCARIOS', Temp.BANCARIOS),
                    ('LIMPIEZA', Temp.LIMPIEZA),
                    ('ADMINISTRACION', Temp.ADMINISTRACION),
                    ('SEGUROS', Temp.SEGUROS),
                    ('GASTOS GENERALES', Temp.GASTOS_GENERALES),
                    ('SERVICIOS PUBLICOS-Agua', Temp.SERVICIOS_PUBLICOS_Agua),
                    ('SERVICIOS PUBLICOS-Luz', Temp.SERVICIOS_PUBLICOS_Luz)
            ) AS ValoresDespivotados (Categoria, ImporteTexto)
        )

        INSERT INTO #GastosJSONTemp (ConsorcioID, Periodo, Categoria, Importe) -- insertamos los campos de interes en la tabla Temp
        SELECT
            Consorcio.ConsorcioID,
            JsonNoPivot.Periodo,
            JsonNoPivot.Categoria,
            SUM(JsonNoPivot.Importe) AS Importe -- sumamos los importes
        FROM JsonNoPivot
        JOIN infraestructura.Consorcio AS Consorcio
            ON JsonNoPivot.NombreDelConsorcio = Consorcio.NombreDelConsorcio
        WHERE 
            JsonNoPivot.Periodo IS NOT NULL
            AND JsonNoPivot.Importe IS NOT NULL
            AND JsonNoPivot.Categoria IS NOT NULL
            AND JsonNoPivot.Importe > 0
        GROUP BY
            Consorcio.ConsorcioID,
            JsonNoPivot.Periodo,
            JsonNoPivot.Categoria;

        SET @LeidosDeArchivo = (SELECT COUNT(*) * 7 FROM #JsonTemp); -- son 7 categorias

        INSERT INTO contable.GastoOrdinario (Periodo, Categoria, ConsorcioID, Importe) -- insertamos en la tabla fisica
        SELECT
            Temp.Periodo,
            Temp.Categoria,
            Temp.ConsorcioID,
            Temp.Importe
        FROM #GastosJSONTemp AS Temp
        WHERE NOT EXISTS (
            SELECT 1
            FROM contable.GastoOrdinario AS GastoOrdinario 
            WHERE 
                GastoOrdinario.Periodo = Temp.Periodo
                AND GastoOrdinario.Categoria = Temp.Categoria
                AND GastoOrdinario.ConsorcioID = Temp.ConsorcioID
        );
        
        SET @Insertados = @@ROWCOUNT; 
        
        SET @ReporteXML = (
            SELECT 
                @RutaArchivo AS 'NombreArchivo',
                @LeidosDeArchivo AS 'RegistrosLeidos',
                @Insertados AS 'Insertados',
                @Corruptos AS 'Corruptos'
            FOR XML PATH('ReporteXMLRegistros')
        );

        EXEC general.p_RegistrarLog 
            @Proceso = @Proceso,
            @Tipo = 'INFO',
            @Mensaje = 'Proceso de importacion de Gastos Ordinarios JSON completado',
            @ReporteXML = @ReporteXML;
            
    END TRY
    BEGIN CATCH

        EXEC general.p_RegistrarLog 
            @Proceso = @Proceso,
            @Tipo = 'ERROR',
            @Mensaje = 'Fallo la importacion';

    END CATCH

    PRINT CHAR(10) + '============== FIN DE p_ImportarGastosOrdinariosJSON ==============';
END
GO
/**********************************************************
 * Bases de Datos Aplicada - Comisión 5600
 * GRUPO 09
 *
 * Archivo: 03_CreacionSPImportarInquilinoPropietariosDatos.sql
 * Enunciado cumplimentado: Creación del SP para importar 
 * el maestro Inquilino-Propietarios-Datos.csv
 *
 * Integrantes:
 * - Ludmila Daiana Ibarra Sánchez DNI 42537300
 * - Gianluca Ferreyra DNI 46026937
 * - Rodrigo Ezequiel Maranzana DNI 41853030
 *********************************************************/

USE Com5600G09;
GO

CREATE OR ALTER PROCEDURE importar.p_ImportarPersonasYCuentasBancarias
    @RutaArchivo VARCHAR(260)
AS
BEGIN
    SET NOCOUNT ON;

    PRINT CHAR(10) + '============== INCIO DE p_ImportarPersonasYCuentasBancarias ==============';

    DROP TABLE IF EXISTS #PersonaYCuentaCSVTemp;
    DROP TABLE IF EXISTS #PersonaYCuentaLimpio;
    DROP TABLE IF EXISTS #PersonasPropInq;

    CREATE TABLE #PersonaYCuentaCSVTemp (
        Nombre VARCHAR(255) COLLATE Latin1_General_CI_AI,
        Apellido VARCHAR(255) COLLATE Latin1_General_CI_AI, 
        DNI VARCHAR(255) COLLATE Latin1_General_CI_AI,
        EmailPersonal VARCHAR(255) COLLATE Latin1_General_CI_AI,
        Telefono VARCHAR(255) COLLATE Latin1_General_CI_AI,
        CvuCbu VARCHAR(255) COLLATE Latin1_General_CI_AI,
        Inquilino VARCHAR(255) COLLATE Latin1_General_CI_AI,
    );

    BEGIN TRY

        ----------------------------------------------------------------------------------------------------------------------------------
        /* BLOQUE GENERAL */
        ----------------------------------------------------------------------------------------------------------------------------------

        DECLARE @Proceso VARCHAR(128) = 'importar.p_ImportarPersonasYCuentasBancarias';

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

        /** Excel al ver numeros grandes, como el CBU/CVU, lo transoforma en notacion decimal daniando permanentemente
        la informacion de esa columna. El archivo .csv no debe ser manipulado previamente. **/
        SET @BulkInsert = N'
            BULK INSERT #PersonaYCuentaCSVTemp
            FROM ''' + @RutaArchivo + '''
            WITH (
                FIELDTERMINATOR = '';'',
                ROWTERMINATOR = ''0x0d0a'', -- según notepad es Windows CR LF, este sería el salto de línea ''\r\n''
                FIRSTROW = 2,               -- omitimos el header y evitamos leer errores como " teléfono de contacto"
                CODEPAGE = ''OEM''          -- según notepad el encoding es ANSI (ACP) pero es incorrecto, debe ser OEM
            );';
        
        EXEC sp_executesql @BulkInsert;
        SET @LeidosDeArchivo = @@ROWCOUNT;

        ALTER TABLE #PersonaYCuentaCSVTemp ADD RegistroID INT IDENTITY(1,1);

        ----------------------------------------------------------------------------------------------------------------------------------
        /* NORMALIZACION Y FILTRADO */
        ----------------------------------------------------------------------------------------------------------------------------------

        WITH CTE AS ( -- limpio los registros de la tabla y doy formato
            SELECT
                RegistroID,
                CAST(UPPER(LTRIM(RTRIM(Nombre))) AS VARCHAR(255)) AS Nombre,
                CAST(UPPER(LTRIM(RTRIM(Apellido))) AS VARCHAR(255))  AS Apellido, 
                TRY_CAST(general.f_NormalizarDNI(DNI) AS INT) AS DNI,
                general.f_NormalizarMail(EmailPersonal) AS Mail,
                general.f_NormalizarTelefono(Telefono) AS Telefono,
                CASE WHEN general.f_RemoverBlancos(CvuCbu) LIKE '%[^0-9]%' THEN NULL ELSE CAST(general.f_RemoverBlancos(CvuCbu) AS VARCHAR(22)) END AS NroClaveUniforme,
                TRY_CAST(Inquilino AS BIT) AS EsInquilino
            FROM #PersonaYCuentaCSVTemp
        )
        SELECT *, -- con ROW_NUMBER cuento la cantidad de veces que se repiten registros con mismo dni nombre y apellido
        ROW_NUMBER() OVER (PARTITION BY DNI, Nombre, Apellido ORDER BY RegistroID) AS CantApariciones 
        INTO #PersonaYCuentaLimpio
        FROM CTE
        WHERE
            CTE.DNI IS NOT NULL AND
            NULLIF(CTE.Nombre, '') IS NOT NULL AND
            NULLIF(CTE.Apellido, '') IS NOT NULL AND
            NULLIF(CTE.Telefono, '') IS NOT NULL AND
            NULLIF(CTE.NroClaveUniforme, '') IS NOT NULL;

        SET @Corruptos = @LeidosDeArchivo - @@ROWCOUNT;
        SET @DuplicadosEnArchivo = (SELECT COUNT(*) FROM #PersonaYCuentaLimpio WHERE CantApariciones > 1);
        ----------------------------------------------------------------------------------------------------------------------------------
        /* UPDATE DE FILAS DE LA TABLA FISICA persona.Persona */
        ----------------------------------------------------------------------------------------------------------------------------------
 
        UPDATE Persona
        SET 
            Persona.Mail = Limpio.Mail,
            Persona.Telefono = Limpio.Telefono,
            Persona.EsPropietario = CASE WHEN Limpio.EsInquilino = 1 THEN 0 ELSE 1 END
        FROM persona.Persona AS Persona
        JOIN #PersonaYCuentaLimpio AS Limpio
            ON (
                Persona.DNI = Limpio.DNI AND
                Persona.Nombre = Limpio.Nombre AND
                Persona.Apellido = Limpio.Apellido
            )
        WHERE (
            ISNULL(Persona.Mail, '') <> ISNULL(Limpio.Mail, '') OR 
            ISNULL(Persona.Telefono, '') <> ISNULL(Limpio.Telefono, '') OR
            Persona.EsPropietario <> (CASE WHEN Limpio.EsInquilino = 1 THEN 0 ELSE 1 END) -- Comparamos el nuevo campo
        )
        SET @Actualizados = @@ROWCOUNT;

        ----------------------------------------------------------------------------------------------------------------------------------
        /* INSERT DE FILAS NUEVAS EN LA TABLA FISICA persona.Persona */
        ----------------------------------------------------------------------------------------------------------------------------------
        
        INSERT INTO persona.Persona (DNI, Nombre, Apellido, Mail, Telefono, EsPropietario)
        SELECT
            Limpio.DNI,
            Limpio.Nombre,
            Limpio.Apellido,
            Limpio.Mail,
            Limpio.Telefono,
            CASE WHEN Limpio.EsInquilino = 1 THEN 0 ELSE 1 END AS EsPropietario
        FROM #PersonaYCuentaLimpio AS Limpio
        WHERE 
            Limpio.CantApariciones = 1 AND-- filtra repetidos en el archivo (mejora la eficiencia al evitar el select)
            NOT EXISTS( -- filtra repetidos en la tabla fisica
                SELECT 1
                FROM persona.Persona AS Persona
                WHERE
                    Persona.DNI = Limpio.DNI AND
                    Persona.Nombre = Limpio.Nombre AND
                    Persona.Apellido = Limpio.Apellido
            )  
        SET @Insertados = @@ROWCOUNT;
        SET @DuplicadosEnTabla = @LeidosDeArchivo - @Insertados - @Corruptos;

        ----------------------------------------------------------------------------------------------------------------------------------
        /* REPORTE Y LOG persona.Persona */
        ----------------------------------------------------------------------------------------------------------------------------------

        SET @ReporteXML = (
            SELECT 
                @LeidosDeArchivo AS 'LeidosArchivo',
                @Insertados AS 'Insertados',
                @Actualizados AS 'Actualizados',
                @DuplicadosEnArchivo AS 'DuplicadosArchivo',
                @DuplicadosEnTabla AS 'DuplicadosTabla',
                @Corruptos AS 'Corruptos'
            FOR XML PATH('ReporteXMLRegistros')
        );

        EXEC general.p_RegistrarLog 
            @Proceso = @Proceso,
            @Tipo = 'INFO',
            @Mensaje = 'Proceso de importacion de personas completado',
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
                    Temp.Nombre,
                    Temp.Apellido,
                    Temp.DNI,
                    Temp.EmailPersonal,
                    Temp.Telefono,
                    Temp.CvuCbu,
                    Temp.Inquilino
                FOR XML PATH('FilaRechazada'), TYPE -- TYPE genera el reporte XML de forma nativa y no como un texto concatenado
            )
        FROM #PersonaYCuentaCSVTemp AS Temp
        LEFT JOIN #PersonaYCuentaLimpio AS Limpio ON Temp.RegistroID = Limpio.RegistroID
        WHERE Limpio.RegistroID IS NULL OR Limpio.CantApariciones > 1;

        ----------------------------------------------------------------------------------------------------------------------------------



        ----------------------------------------------------------------------------------------------------------------------------------
        /* UPDATE DE FILAS DE LA TABLA FISICA persona.CuentaBancaria */
        ----------------------------------------------------------------------------------------------------------------------------------
        
        -- La tabla de cuenta bancaria no tiene campos que se deban actualizar --
        SET @Actualizados = 0;

        ----------------------------------------------------------------------------------------------------------------------------------
        /* INSERT DE FILAS NUEVAS EN LA TABLA FISICA persona.CuentaBancaria */
        ----------------------------------------------------------------------------------------------------------------------------------

        INSERT INTO persona.CuentaBancaria (NroClaveUniformeID, PersonaID)
        SELECT DISTINCT
            Limpio.NroClaveUniforme,
            Persona.PersonaID
        FROM #PersonaYCuentaLimpio AS Limpio
        JOIN persona.Persona AS Persona
            ON (
                Persona.DNI = Limpio.DNI AND
                Persona.Nombre = Limpio.Nombre AND
                Persona.Apellido = Limpio.Apellido
            )
        WHERE 
            Limpio.CantApariciones = 1 AND-- filtra repetidos en el archivo (mejora la eficiencia al evitar el select)
            NOT EXISTS( -- filtra repetidos en la tabla fisica
                SELECT 1
                FROM persona.CuentaBancaria AS CuentaBancaria
                WHERE
                    CuentaBancaria.NroClaveUniformeID = Limpio.NroClaveUniforme
            ) 
        SET @Insertados = @@ROWCOUNT;

        ----------------------------------------------------------------------------------------------------------------------------------
        /* REPORTE Y LOG persona.CuentaBancaria */
        ----------------------------------------------------------------------------------------------------------------------------------

        SET @ReporteXML = (
            SELECT 
                @LeidosDeArchivo AS 'LeidosArchivo',
                @Insertados AS 'Insertados',
                @Actualizados AS 'Actualizados',
                @DuplicadosEnArchivo AS 'DuplicadosArchivo',
                @DuplicadosEnTabla AS 'DuplicadosTabla',
                @Corruptos AS 'Corruptos'
            FOR XML PATH('ReporteXMLRegistros')
        );

        EXEC general.p_RegistrarLog 
            @Proceso = @Proceso,
            @Tipo = 'INFO',
            @Mensaje = 'Proceso de importacion de cuentas bancarias completado',
            @ReporteXML = @ReporteXML;

        ----------------------------------------------------------------------------------------------------------------------------------

    END TRY
    BEGIN CATCH
      
        EXEC general.p_RegistrarLog 
            @Proceso = @Proceso,
            @Tipo = 'ERROR',
            @Mensaje = 'Fallo la importación';
    
    END CATCH

    PRINT CHAR(10) + '============== FIN DE p_ImportarPersonasYCuentasBancarias ==============';
END
GO
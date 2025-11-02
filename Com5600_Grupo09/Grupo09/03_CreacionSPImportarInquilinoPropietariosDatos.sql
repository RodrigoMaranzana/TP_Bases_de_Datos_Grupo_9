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

CREATE OR ALTER PROCEDURE importar.p_ImportarHabitantesYCuentasBancarias
    @RutaArchivoCSV VARCHAR(260)
AS
BEGIN
    SET NOCOUNT ON;

    PRINT CHAR(10) + '============== INCIO DE p_ImportarHabitantesYCuentasBancarias ==============';

    CREATE TABLE #HabitanteYCuentaCSVTemp (
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

        DECLARE @BulkInsert NVARCHAR(MAX);

        DECLARE @FilasTotalesCSV INT = 0;
        DECLARE @FilasInsertadas INT = 0;
        DECLARE @FilasCorruptas INT = 0;
        DECLARE @FilasDuplicadas INT = 0;
        
        ----------------------------------------------------------------------------------------------------------------------------------
        /* ARCHIVO CSV */
        ----------------------------------------------------------------------------------------------------------------------------------

        PRINT CHAR(10) + '>>> Iniciando el proceso para el archivo';

        /** Excel al ver numeros grandes, como el CBU/CVU, lo transoforma en notacion decimal daniando permanentemente
        la informacion de esa columna. El archivo .csv no debe ser manipulado previamente. **/
        SET @BulkInsert = N'
            BULK INSERT #HabitanteYCuentaCSVTemp
            FROM ''' + @RutaArchivoCSV + '''
            WITH (
                FIELDTERMINATOR = '';'',
                ROWTERMINATOR = ''0x0d0a'', -- según notepad es Windows CR LF, este sería el salto de línea ''\r\n''
                FIRSTROW = 2,               -- omitimos el header y evitamos leer errores como " teléfono de contacto"
                CODEPAGE = ''OEM''          -- según notepad el encoding es ANSI (ACP) pero es incorrecto, debe ser OEM
            );';
        
        EXEC sp_executesql @BulkInsert;

        SELECT @FilasTotalesCSV = COUNT(*) FROM #HabitanteYCuentaCSVTemp;
        PRINT  CHAR(10) + '>>> El archivo se cargo en #HabitanteYCuentaCSVTemp.' + CHAR(10) + '     Filas totales: ' + CAST(@FilasTotalesCSV AS VARCHAR(10));

        ALTER TABLE #HabitanteYCuentaCSVTemp ADD RegistroID INT IDENTITY(1,1);

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
            FROM #HabitanteYCuentaCSVTemp
        )
        SELECT *, -- con ROW_NUMBER cuento la cantidad de veces que se repiten registros con mismo dni nombre y apellido
        ROW_NUMBER() OVER (PARTITION BY DNI, Nombre, Apellido ORDER BY RegistroID) AS CantApariciones 
        INTO #HabitanteYCuentaLimpio
        FROM CTE
        WHERE
            CTE.DNI IS NOT NULL AND
            NULLIF(CTE.Nombre, '') IS NOT NULL AND
            NULLIF(CTE.Apellido, '') IS NOT NULL AND
            NULLIF(CTE.Telefono, '') IS NOT NULL AND
            NULLIF(CTE.NroClaveUniforme, '') IS NOT NULL;

        SET @FilasCorruptas = @FilasTotalesCSV - @@ROWCOUNT;

        -- informamos que un registro fue rechazado por corrupto
        SELECT Temp.*,
            CASE 
                WHEN Limpio.RegistroID IS NULL THEN 'Rechazado: Corrupto'
                ELSE 'Rechazado: Duplicado en el archivo'
            END AS Estado
        FROM #HabitanteYCuentaCSVTemp AS Temp
        LEFT JOIN #HabitanteYCuentaLimpio AS Limpio
            ON Temp.RegistroID = Limpio.RegistroID
        WHERE -- se muestran los que no estan en la tabla limpia o los que estan duplicados en el archivo
            Limpio.RegistroID IS NULL
            OR Limpio.CantApariciones > 1;

        ----------------------------------------------------------------------------------------------------------------------------------
        /* UPDATE DE FILAS DE LA TABLA FISICA persona.Habitante */
        ----------------------------------------------------------------------------------------------------------------------------------
 
        UPDATE Habitante
        SET -- estos son los campos que considero se deberian poder actualizar
            Habitante.Mail = Limpio.Mail,
            Habitante.Telefono = Limpio.Telefono,
            Habitante.EsInquilino = Limpio.EsInquilino
        FROM persona.Habitante AS Habitante
        JOIN #HabitanteYCuentaLimpio AS Limpio
            ON (
                Habitante.DNI = Limpio.DNI AND
                Habitante.Nombre = Limpio.Nombre AND
                Habitante.Apellido = Limpio.Apellido
            )
        WHERE (
            ISNULL(Habitante.Mail, '') <> ISNULL(Limpio.Mail, '') OR -- ISNULL() permite actualizar en caso de que la primera vez se haya insertado NULL en la tabla
            ISNULL(Habitante.Telefono, '') <> ISNULL(Limpio.Telefono, '') OR
            ISNULL(Habitante.EsInquilino, '') <> ISNULL(Limpio.EsInquilino, '')
        )

        ----------------------------------------------------------------------------------------------------------------------------------
        /* INSERT DE FILAS NUEVAS EN LA TABLA FISICA persona.Habitante */
        ----------------------------------------------------------------------------------------------------------------------------------
        
        INSERT INTO persona.Habitante (DNI, Nombre, Apellido, Mail, Telefono, EsInquilino)
        SELECT
            Limpio.DNI,
            Limpio.Nombre,
            Limpio.Apellido,
            Limpio.Mail,
            Limpio.Telefono,
            Limpio.EsInquilino -- si no es correcto el valor cal csv, queda indeterminado para futura actualizacion de novedades
        FROM #HabitanteYCuentaLimpio AS Limpio
        WHERE 
            Limpio.CantApariciones = 1 AND-- filtra repetidos en el archivo (mejora la eficiencia al evitar el select)
            NOT EXISTS( -- filtra repetidos en la tabla fisica
                SELECT 1
                FROM persona.Habitante AS Habitante
                WHERE
                    Habitante.DNI = Limpio.DNI AND
                    Habitante.Nombre = Limpio.Nombre AND
                    Habitante.Apellido = Limpio.Apellido
            )  

        SET @FilasInsertadas = @@ROWCOUNT; -- la cantidad de filas que fueron afectadas por el INSERT
        SET @FilasDuplicadas = @FilasTotalesCSV - @FilasInsertadas - @FilasCorruptas;

        EXEC general.p_RegistrarLogImportacion
            @NombreImportacion = 'persona.Habitante',
            @FilasInsertadas = @FilasInsertadas,
            @FilasDuplicadas = @FilasDuplicadas,
            @FilasCorruptas = @FilasCorruptas,
            @Detalle = 'Proceso completado con normalidad.',
            @MostrarPorConsola = 1;

        ----------------------------------------------------------------------------------------------------------------------------------
        /* UPDATE DE FILAS DE LA TABLA FISICA persona.CuentaBancaria */
        ----------------------------------------------------------------------------------------------------------------------------------
        
        -- La tabla de cuenta bancaria no tiene campos que se deban actualizar --

        ----------------------------------------------------------------------------------------------------------------------------------
        /* INSERT DE FILAS NUEVAS EN LA TABLA FISICA persona.CuentaBancaria */
        ----------------------------------------------------------------------------------------------------------------------------------

        INSERT INTO persona.CuentaBancaria (NroClaveUniformeID, DNI, Nombre, Apellido)
        SELECT DISTINCT
            Limpio.NroClaveUniforme,
            Limpio.DNI,
            Limpio.Nombre,
            Limpio.Apellido
        FROM #HabitanteYCuentaLimpio AS Limpio
        WHERE 
            Limpio.CantApariciones = 1 AND-- filtra repetidos en el archivo (mejora la eficiencia al evitar el select)
            NOT EXISTS( -- filtra repetidos en la tabla fisica
                SELECT 1
                FROM persona.CuentaBancaria AS CuentaBancaria
                WHERE
                    CuentaBancaria.NroClaveUniformeID = Limpio.NroClaveUniforme
            ) 

        SET @FilasInsertadas = @@ROWCOUNT; -- la cantidad de filas que fueron afectadas por el INSERT
        SET @FilasDuplicadas = @FilasTotalesCSV - @FilasInsertadas - @FilasCorruptas;

        EXEC general.p_RegistrarLogImportacion
            @NombreImportacion = 'persona.CuentaBancaria',
            @FilasInsertadas = @FilasInsertadas,
            @FilasDuplicadas = @FilasDuplicadas,
            @FilasCorruptas = @FilasCorruptas,
            @Detalle = 'Proceso completado con normalidad.',
            @MostrarPorConsola = 1;

        ----------------------------------------------------------------------------------------------------------------------------------

    END TRY
    BEGIN CATCH
      
        EXEC general.p_RegistrarLogImportacion
            @NombreImportacion = 'persona.Habitante',
            @FilasInsertadas = @FilasInsertadas,
            @FilasDuplicadas = @FilasDuplicadas,
            @FilasCorruptas = @FilasCorruptas,
            @Detalle = 'Error: No se pudo cargar el archivo CSV.',
            @MostrarPorConsola = 1;

        DECLARE @ErrorMessage NVARCHAR(4000);
        SELECT @ErrorMessage = ERROR_MESSAGE()
        PRINT @ErrorMessage;
    
    END CATCH

    PRINT CHAR(10) + '============== FIN DE p_ImportarHabitantesYCuentasBancarias ==============';

    DROP TABLE IF EXISTS #HabitanteYCuentaCSVTemp;
    DROP TABLE IF EXISTS #HabitanteYCuentaLimpio;
END
GO
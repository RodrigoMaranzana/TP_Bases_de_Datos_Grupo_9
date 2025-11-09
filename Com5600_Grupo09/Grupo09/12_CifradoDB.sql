/**********************************************************
 * Bases de Datos Aplicada - Comisión 5600
 * GRUPO 09
 *
 * Archivo: 12_CifradoDB.sql
 * Enunciado cumplimentado: Cifrado de los datos personales contenidos
 * en la Base de Datos
 *
 * Integrantes:
 * - Ludmila Daiana Ibarra Sánchez DNI 42537300
 * - Gianluca Ferreyra DNI 46026937
 * - Rodrigo Ezequiel Maranzana DNI 41853030
 *********************************************************/

USE Com5600G09;
GO

----------------------------------------------------------------------------------------------------------------------------------
    /* Certificado para la encriptacion de los datos personales de las Personas */
----------------------------------------------------------------------------------------------------------------------------------

IF NOT EXISTS (SELECT 1 FROM sys.symmetric_keys WHERE name = 'KeyPersonas')
BEGIN
    CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'Grupo_09_Trabajo#Practico!BDA';
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.certificates WHERE name = 'CertificadoPersonas')
BEGIN
    CREATE CERTIFICATE CertificadoPersonas
       WITH SUBJECT = 'Certificado para datos personales de los Personas';
END
GO

-- creamos una clave simetrica ya que no se necesita compartir la clave y es mas rapida que la asimetrica
IF NOT EXISTS (SELECT 1 FROM sys.symmetric_keys WHERE name = 'KeyPersonas')
BEGIN
    CREATE SYMMETRIC KEY KeyPersonas
    WITH ALGORITHM = AES_256
    ENCRYPTION BY CERTIFICATE CertificadoPersonas;
END
GO


----------------------------------------------------------------------------------------------------------------------------------
    /* Inicio de la Alteracion de tablas (eliminacion de las restricciones y indices que generan dependencias) */
----------------------------------------------------------------------------------------------------------------------------------


IF OBJECT_ID('infraestructura.FK_UnidadFuncional_CuentaBancaria', 'F') IS NOT NULL
BEGIN
    ALTER TABLE infraestructura.UnidadFuncional 
    DROP CONSTRAINT FK_UnidadFuncional_CuentaBancaria;
END
GO

IF OBJECT_ID('contable.FK_Pago_CuentaBancaria', 'F') IS NOT NULL
BEGIN
    ALTER TABLE contable.Pago 
    DROP CONSTRAINT FK_Pago_CuentaBancaria;
END
GO

IF EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID('contable.Pago') AND name = 'IX_Pago_Fecha')
BEGIN
    DROP INDEX IX_Pago_Fecha ON contable.Pago;
END
GO

IF EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID('persona.CuentaBancaria') AND name = 'IX_CuentaBancaria_PersonaID')
BEGIN
    DROP INDEX IX_CuentaBancaria_PersonaID ON persona.CuentaBancaria;
END
GO

----------------------------------------------------------------------------------------------------------------------------------
    /* Alteracion de la tabla persona.CuentaBancaria para el cifrado de la Clave Uniforme */
----------------------------------------------------------------------------------------------------------------------------------


IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('persona.CuentaBancaria') AND name = 'CuentaBancariaID')
BEGIN
    ALTER TABLE persona.CuentaBancaria DROP CONSTRAINT CK_CuentaBancaria_NroClaveUniformeValido;
    ALTER TABLE persona.CuentaBancaria DROP CONSTRAINT PK_CuentaBancaria;
    ALTER TABLE persona.CuentaBancaria
    ADD CuentaBancariaID INT IDENTITY(1,1) NOT NULL PRIMARY KEY;
    ALTER TABLE persona.CuentaBancaria
    ADD NroClaveUniformeIDCifrado VARBINARY(256) NULL, NroClaveUniformeIDHash BINARY(32) NULL;
END
GO

IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('persona.CuentaBancaria') AND name = 'NroClaveUniformeID' AND system_type_id <> TYPE_ID('varbinary'))
BEGIN
    OPEN SYMMETRIC KEY KeyPersonas
    DECRYPTION BY CERTIFICATE CertificadoPersonas;

    UPDATE persona.CuentaBancaria
    SET
        NroClaveUniformeIDCifrado = EncryptByKey(KEY_GUID('KeyPersonas'), NroClaveUniformeID),
        NroClaveUniformeIDHash = HASHBYTES('SHA2_256', NroClaveUniformeID)
    WHERE NroClaveUniformeID IS NOT NULL;

    CLOSE SYMMETRIC KEY KeyPersonas;

    ALTER TABLE persona.CuentaBancaria
    DROP COLUMN NroClaveUniformeID;

    EXEC sp_rename 'persona.CuentaBancaria.NroClaveUniformeIDCifrado', 'NroClaveUniformeID', 'COLUMN';
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID('persona.CuentaBancaria') AND name = 'IX_CuentaBancaria_Hash')
BEGIN
    CREATE NONCLUSTERED INDEX IX_CuentaBancaria_Hash
    ON persona.CuentaBancaria (NroClaveUniformeIDHash);
END
GO


----------------------------------------------------------------------------------------------------------------------------------
    /* Alteracion de la tabla persona.Persona para el cifrado de los datos personales */
----------------------------------------------------------------------------------------------------------------------------------


IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('persona.Persona') AND name = 'DNI_Cifrado')
BEGIN
    ALTER TABLE persona.Persona DROP CONSTRAINT UQ_Persona_Unica;
    ALTER TABLE persona.Persona DROP CONSTRAINT CK_Persona_MailValido;
    ALTER TABLE persona.Persona DROP CONSTRAINT CK_Persona_TelefonoValido;
    ALTER TABLE persona.Persona DROP CONSTRAINT CK_Persona_DNIValido;

    ALTER TABLE persona.Persona
    ADD DNI_Cifrado VARBINARY(256) NULL,
        DNI_Hash BINARY(32) NULL,
        Nombre_Cifrado VARBINARY(256) NULL,
        Nombre_Hash BINARY(32) NULL,
        Apellido_Cifrado VARBINARY(256) NULL,
        Apellido_Hash BINARY(32) NULL,
        Mail_Cifrado VARBINARY(256) NULL,
        Telefono_Cifrado VARBINARY(256) NULL;
END
GO

IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('persona.Persona') AND name = 'DNI' AND system_type_id <> TYPE_ID('varbinary'))
BEGIN
    OPEN SYMMETRIC KEY KeyPersonas
    DECRYPTION BY CERTIFICATE CertificadoPersonas;

    UPDATE persona.Persona
    SET
        DNI_Cifrado = EncryptByKey(KEY_GUID('KeyPersonas'), CAST(DNI AS VARCHAR(20))),
        DNI_Hash = HASHBYTES('SHA2_256', CAST(DNI AS VARCHAR(20))),
        Nombre_Cifrado = EncryptByKey(KEY_GUID('KeyPersonas'), Nombre),
        Nombre_Hash = HASHBYTES('SHA2_256', Nombre),
        Apellido_Cifrado = EncryptByKey(KEY_GUID('KeyPersonas'), Apellido),
        Apellido_Hash = HASHBYTES('SHA2_256', Apellido),
        Mail_Cifrado = EncryptByKey(KEY_GUID('KeyPersonas'), Mail),
        Telefono_Cifrado = EncryptByKey(KEY_GUID('KeyPersonas'), Telefono)
    WHERE PersonaID IS NOT NULL;

    CLOSE SYMMETRIC KEY KeyPersonas;

    ALTER TABLE persona.Persona DROP COLUMN DNI;
    ALTER TABLE persona.Persona DROP COLUMN Nombre;
    ALTER TABLE persona.Persona DROP COLUMN Apellido;
    ALTER TABLE persona.Persona DROP COLUMN Mail;
    ALTER TABLE persona.Persona DROP COLUMN Telefono;

    EXEC sp_rename 'persona.Persona.DNI_Cifrado', 'DNI', 'COLUMN';
    EXEC sp_rename 'persona.Persona.Nombre_Cifrado', 'Nombre', 'COLUMN';
    EXEC sp_rename 'persona.Persona.Apellido_Cifrado', 'Apellido', 'COLUMN';
    EXEC sp_rename 'persona.Persona.Mail_Cifrado', 'Mail', 'COLUMN';
    EXEC sp_rename 'persona.Persona.Telefono_Cifrado', 'Telefono', 'COLUMN';
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.key_constraints WHERE object_id = OBJECT_ID('persona.UQ_Persona_Unica_Hash'))
BEGIN
    ALTER TABLE persona.Persona -- creamos el UNIQUE nuevamnete
    ADD CONSTRAINT UQ_Persona_Unica_Hash
        UNIQUE (DNI_Hash, Nombre_Hash, Apellido_Hash);
END
GO

----------------------------------------------------------------------------------------------------------------------------------
    /* Alteracion de la tabla infraestructura.UnidadFuncional para el cifrado de la Clave Uniforme */
----------------------------------------------------------------------------------------------------------------------------------

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('infraestructura.UnidadFuncional') AND name = 'CuentaBancariaID')
BEGIN
    ALTER TABLE infraestructura.UnidadFuncional
    ADD CuentaBancariaID INT NULL;
END
GO

IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('infraestructura.UnidadFuncional') AND name = 'NroClaveUniformeID')
BEGIN
    UPDATE UnidadFuncional
    SET
        UnidadFuncional.CuentaBancariaID = CuentaBancaria.CuentaBancariaID
    FROM infraestructura.UnidadFuncional AS UnidadFuncional
    JOIN persona.CuentaBancaria AS CuentaBancaria 
        ON HASHBYTES('SHA2_256', UnidadFuncional.NroClaveUniformeID) = CuentaBancaria.NroClaveUniformeIDHash
    WHERE UnidadFuncional.NroClaveUniformeID IS NOT NULL;

    ALTER TABLE infraestructura.UnidadFuncional
    DROP COLUMN NroClaveUniformeID;

    ALTER TABLE infraestructura.UnidadFuncional -- cambiamos la FK por el ID identity nuevo de la tabla persona.CuentaBancaria
    ADD CONSTRAINT FK_UnidadFuncional_CuentaBancaria FOREIGN KEY (CuentaBancariaID) 
        REFERENCES persona.CuentaBancaria(CuentaBancariaID);
END
GO


----------------------------------------------------------------------------------------------------------------------------------
    /* Alteracion de la tabla contable.Pago para el cifrado de la Clave Uniforme */
----------------------------------------------------------------------------------------------------------------------------------


IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('contable.Pago') AND name = 'CuentaBancariaID')
BEGIN
    ALTER TABLE contable.Pago
    ADD CuentaBancariaID INT NULL;
END
GO

IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('contable.Pago') AND name = 'NroClaveUniformeID')
BEGIN
    UPDATE Pago
    SET
        Pago.CuentaBancariaID = CuentaBancaria.CuentaBancariaID
    FROM contable.Pago AS Pago
    JOIN persona.CuentaBancaria AS CuentaBancaria 
        ON HASHBYTES('SHA2_256', Pago.NroClaveUniformeID) = CuentaBancaria.NroClaveUniformeIDHash
    WHERE Pago.NroClaveUniformeID IS NOT NULL;

    ALTER TABLE contable.Pago
    DROP COLUMN NroClaveUniformeID;

    ALTER TABLE contable.Pago
    ALTER COLUMN CuentaBancariaID INT NOT NULL;

    ALTER TABLE contable.Pago
    ADD CONSTRAINT FK_Pago_CuentaBancaria FOREIGN KEY (CuentaBancariaID) -- cambiamos la FK por el ID identity nuevo de la tabla persona.CuentaBancaria
        REFERENCES persona.CuentaBancaria(CuentaBancariaID);
END
GO


----------------------------------------------------------------------------------------------------------------------------------
    /* Creacion de los indices modificados */
----------------------------------------------------------------------------------------------------------------------------------


IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Pago_Fecha' AND object_id = OBJECT_ID('contable.Pago'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_Pago_Fecha
    ON contable.Pago (Fecha)
    INCLUDE (CuentaBancariaID, Importe, Concepto); 
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_CuentaBancaria_PersonaID' AND object_id = OBJECT_ID('persona.CuentaBancaria'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_CuentaBancaria_PersonaID 
    ON persona.CuentaBancaria (PersonaID)
    INCLUDE (NroClaveUniformeIDHash, CuentaBancariaID); 
END
GO


----------------------------------------------------------------------------------------------------------------------------------
    /* Alteracion del SP importar.p_ImportarPersonasYCuentasBancarias */
----------------------------------------------------------------------------------------------------------------------------------


CREATE OR ALTER PROCEDURE importar.p_ImportarPersonasYCuentasBancarias
    @RutaArchivo VARCHAR(260)
AS
BEGIN
    SET NOCOUNT ON;

    PRINT CHAR(10) + '============== INCIO DE p_ImportarPersonasYCuentasBancarias ==============';

    DROP TABLE IF EXISTS #PersonaYCuentaCSVTemp;
    DROP TABLE IF EXISTS #PersonaYCuentaLimpio;
    DROP TABLE IF EXISTS #PersonasPropInq;
    DROP TABLE IF EXISTS #PersonasHash;

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
                FIRSTROW = 2,           -- omitimos el header y evitamos leer errores como " teléfono de contacto"
                CODEPAGE = ''OEM''         -- según notepad el encoding es ANSI (ACP) pero es incorrecto, debe ser OEM
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
        
        SELECT *, -- creamos aca los hashes para los datos
            CAST(DNI AS VARCHAR(20)) AS DNI_varchar,
            HASHBYTES('SHA2_256', CAST(DNI AS VARCHAR(20))) AS DNI_Hash,
            HASHBYTES('SHA2_256', Nombre) AS Nombre_Hash,
            HASHBYTES('SHA2_256', Apellido) AS Apellido_Hash,
            HASHBYTES('SHA2_256', NroClaveUniforme) AS NroClaveUniforme_Hash
        INTO #PersonasHash
        FROM #PersonaYCuentaLimpio
        WHERE CantApariciones = 1;

        ----------------------------------------------------------------------------------------------------------------------------------
        /* UPDATE DE FILAS DE LA TABLA FISICA persona.Persona */
        ----------------------------------------------------------------------------------------------------------------------------------
        
        OPEN SYMMETRIC KEY KeyPersonas
        DECRYPTION BY CERTIFICATE CertificadoPersonas;

        UPDATE Persona
        SET 
            Persona.Mail = EncryptByKey(KEY_GUID('KeyPersonas'), Limpio.Mail),
            Persona.Telefono = EncryptByKey(KEY_GUID('KeyPersonas'), Limpio.Telefono),
            Persona.EsPropietario = CASE WHEN Limpio.EsInquilino = 1 THEN 0 ELSE 1 END
        FROM persona.Persona AS Persona
        JOIN #PersonasHash AS Limpio
            ON (
                Persona.DNI_Hash = Limpio.DNI_Hash AND
                Persona.Nombre_Hash = Limpio.Nombre_Hash AND
                Persona.Apellido_Hash = Limpio.Apellido_Hash
            );
        
        SET @Actualizados = @@ROWCOUNT;

        ----------------------------------------------------------------------------------------------------------------------------------
        /* INSERT DE FILAS NUEVAS EN LA TABLA FISICA persona.Persona */
        ----------------------------------------------------------------------------------------------------------------------------------
        
        INSERT INTO persona.Persona (
            DNI,
            DNI_Hash, 
            Nombre,
            Nombre_Hash, 
            Apellido,
            Apellido_Hash, 
            Mail,
            Telefono,
            EsPropietario
        )
        SELECT
            EncryptByKey(KEY_GUID('KeyPersonas'), Limpio.DNI_varchar),
            Limpio.DNI_Hash,
            EncryptByKey(KEY_GUID('KeyPersonas'), Limpio.Nombre),
            Limpio.Nombre_Hash,
            EncryptByKey(KEY_GUID('KeyPersonas'), Limpio.Apellido),
            Limpio.Apellido_Hash,
            EncryptByKey(KEY_GUID('KeyPersonas'), Limpio.Mail),
            EncryptByKey(KEY_GUID('KeyPersonas'), Limpio.Telefono),
            CASE WHEN Limpio.EsInquilino = 1 THEN 0 ELSE 1 END AS EsPropietario
        FROM #PersonasHash AS Limpio
        WHERE 
            NOT EXISTS( -- filtra repetidos en la tabla fisica
                SELECT 1
                FROM persona.Persona AS Persona
                WHERE
                    Persona.DNI_Hash = Limpio.DNI_Hash AND
                    Persona.Nombre_Hash = Limpio.Nombre_Hash AND
                    Persona.Apellido_Hash = Limpio.Apellido_Hash
            )  
        SET @Insertados = @@ROWCOUNT;
        
        CLOSE SYMMETRIC KEY KeyPersonas;

        SET @DuplicadosEnTabla = (SELECT COUNT(*) FROM #PersonasHash) - @Insertados - @Actualizados; -- Lógica de conteo ajustada

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
        
        -- La tabla de cuenta bancaria no tiene campos que se deban actualizar
        SET @Actualizados = 0;

        ----------------------------------------------------------------------------------------------------------------------------------
        /* INSERT DE FILAS NUEVAS EN LA TABLA FISICA persona.CuentaBancaria */
        ----------------------------------------------------------------------------------------------------------------------------------

        OPEN SYMMETRIC KEY KeyPersonas
        DECRYPTION BY CERTIFICATE CertificadoPersonas;

        INSERT INTO persona.CuentaBancaria (NroClaveUniformeID, NroClaveUniformeIDHash, PersonaID)
        SELECT DISTINCT
            EncryptByKey(KEY_GUID('KeyPersonas'), Limpio.NroClaveUniforme),
            Limpio.NroClaveUniforme_Hash,
            Persona.PersonaID
        FROM #PersonasHash AS Limpio
        JOIN persona.Persona AS Persona
            ON (
                Persona.DNI_Hash = Limpio.DNI_Hash AND
                Persona.Nombre_Hash = Limpio.Nombre_Hash AND
                Persona.Apellido_Hash = Limpio.Apellido_Hash
            )
        WHERE 
            NOT EXISTS( -- filtra repetidos en la tabla fisica
                SELECT 1
                FROM persona.CuentaBancaria AS CuentaBancaria
                WHERE
                    CuentaBancaria.NroClaveUniformeIDHash = Limpio.NroClaveUniforme_Hash
            ) 
        SET @Insertados = @@ROWCOUNT;

        CLOSE SYMMETRIC KEY KeyPersonas;

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
        
        IF (SELECT KEY_GUID('KeyPersonas')) IS NOT NULL -- cerramos la llave en caso de catch
        BEGIN
            CLOSE SYMMETRIC KEY KeyPersonas;
        END

        EXEC general.p_RegistrarLog 
            @Proceso = @Proceso,
            @Tipo = 'ERROR',
            @Mensaje = 'Fallo la importación';
        
    END CATCH

    PRINT CHAR(10) + '============== FIN DE p_ImportarPersonasYCuentasBancarias ==============';
END
GO


----------------------------------------------------------------------------------------------------------------------------------
    /* Alteracion del SP importar.p_ImportarInquilinoPropietarioPorClaveUniformePorUF */
----------------------------------------------------------------------------------------------------------------------------------

CREATE OR ALTER PROCEDURE importar.p_ImportarInquilinoPropietarioPorClaveUniformePorUF
    @RutaArchivo VARCHAR(260)
AS
BEGIN
    SET NOCOUNT ON;

    PRINT CHAR(10) + '============== INCIO DE p_ImportarInquilinoPropietarioPorClaveUniformePorUF ==============';

    DROP TABLE IF EXISTS #ClaveUniformePorUFCSVTemp;
    DROP TABLE IF EXISTS #ClaveUniformePorUFLimpio;
    DROP TABLE IF EXISTS #ClaveUniformePorUFLimpioHash;

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
        SELECT *, HASHBYTES('SHA2_256', NroClaveUniforme) AS NroClaveUniforme_Hash
        INTO #ClaveUniformePorUFLimpioHash
        FROM CTEFormato
        WHERE CTEFormato.NroClaveUniforme IS NOT NULL;

        SELECT -- especificamos los campos para que no genere ambieguedad con el join el NombreDelConsorcio
            LimpioHash.RegistroID,
            LimpioHash.NroClaveUniforme,
            UnidadFuncional.ConsorcioID,
            UnidadFuncional.NroUnidadFuncionalID,
            Persona.PersonaID,
            Persona.EsPropietario,
            CuentaBancaria.CuentaBancariaID,
            ROW_NUMBER() OVER (
                PARTITION BY
                    UnidadFuncional.ConsorcioID,
                    UnidadFuncional.NroUnidadFuncionalID
                ORDER BY H.RegistroID
            ) AS CantApariciones
        INTO #ClaveUniformePorUFLimpio
        FROM #ClaveUniformePorUFLimpioHash AS LimpioHash
        JOIN infraestructura.UnidadFuncional AS UnidadFuncional
            ON LimpioHash.NroUnidadFuncional = UnidadFuncional.NroUnidadFuncionalID AND
            LimpioHash.Piso = UnidadFuncional.Piso AND LimpioHash.Departamento = UnidadFuncional.Departamento
        JOIN infraestructura.Consorcio AS Consorcio
            ON UnidadFuncional.ConsorcioID = Consorcio.ConsorcioID AND
            LimpioHash.NombreDelConsorcio = Consorcio.NombreDelConsorcio
        JOIN persona.CuentaBancaria AS CuentaBancaria
            ON LimpioHash.NroClaveUniforme_Hash = CuentaBancaria.NroClaveUniformeIDHash
        JOIN persona.Persona AS Persona
            ON CuentaBancaria.PersonaID = Persona.PersonaID;

        SET @Corruptos = @LeidosDeArchivo - @@ROWCOUNT;

        ----------------------------------------------------------------------------------------------------------------------------------
        /* UPDATE DE FILAS DE LA TABLA FISICA infraestructura.UnidadFuncional */
        ----------------------------------------------------------------------------------------------------------------------------------
        
        -- con la anterior consulta vinculamos las claves uniformes con las personas titulares de esos CBU, y luego al hacer JOIN con
        -- las tablas Propietarios y Inquilinos obtenemos de que tipo es esa persona para una unidad funcional de un consorcio especifico

        UPDATE UnidadFuncional
        SET 
            UnidadFuncional.PropietarioID = Limpio.PersonaID,
            UnidadFuncional.CuentaBancariaID = Limpio.CuentaBancariaID
        FROM infraestructura.UnidadFuncional AS UnidadFuncional
        JOIN #ClaveUniformePorUFLimpio AS Limpio 
            ON UnidadFuncional.ConsorcioID = Limpio.ConsorcioID AND UnidadFuncional.NroUnidadFuncionalID = Limpio.NroUnidadFuncionalID
        WHERE 
            Limpio.EsPropietario = 1;
        
        SET @UFPropietariosActualizados = @@ROWCOUNT;

        UPDATE UnidadFuncional
        SET 
            UnidadFuncional.InquilinoID = Limpio.PersonaID,
            UnidadFuncional.CuentaBancariaID = Limpio.CuentaBancariaID
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
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

/**

Este script al ser destructivo y alterar permanentemente la base solo puede ejecutarse una vez.
No se incluye en el script Pruebas_EjecutarSPDeImportacion.sql para que se pueda comparar la
funcionalidad pre y post cifrado

**/

----------------------------------------------------------------------------------------------------------------------------------
    /* Certificado para la encriptacion de los datos personales de las Personas */
----------------------------------------------------------------------------------------------------------------------------------

-- crea la llave maestra que se usara para el cifrado
IF NOT EXISTS (SELECT 1 FROM sys.symmetric_keys WHERE name = 'KeyPersonas')
BEGIN
    CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'Grupo_09_Trabajo#Practico!BDA';
END
GO

-- crea el cretificado para protejer la llave simetrica
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
    SET -- al crifrar obtendremos dos resultados binarios distintos
        NroClaveUniformeIDCifrado = EncryptByKey(KEY_GUID('KeyPersonas'), NroClaveUniformeID),
        NroClaveUniformeIDHash = HASHBYTES('SHA2_256', NroClaveUniformeID) -- por esta razon usamos el hash para buscar/comparar
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
        Mail_Cifrado VARBINARY(300) NULL, -- aumentamos el limite para que no se trunque y falle
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
                CAST(UPPER(LTRIM(RTRIM(Nombre))) AS VARCHAR(128)) AS Nombre,
                CAST(UPPER(LTRIM(RTRIM(Apellido))) AS VARCHAR(128))  AS Apellido, 
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
                CAST(UPPER(LTRIM(RTRIM(NombreDelConsorcio))) AS VARCHAR(64)) AS NombreDelConsorcio,
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



----------------------------------------------------------------------------------------------------------------------------------
    /* Alteracion del SP importar.p_GenerarLotePagos */
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

    DROP TABLE IF EXISTS #CuentasBancarias;
    SELECT 
        CuentaBancariaID -- cambio esto para usar el ID para poder comparara y buscar una cuenta bancaria
    INTO #CuentasBancarias 
    FROM 
        persona.CuentaBancaria;

    IF NOT EXISTS (SELECT 1 FROM #CuentasBancarias)
    BEGIN
        PRINT('La tabla persona.CuentaBancaria no tiene registros. No se pueden generar pagos.');
        RETURN;
    END

    DECLARE @i INT = 1;

    BEGIN TRANSACTION;
    WHILE @i <= @Cantidad
    BEGIN
        
        DECLARE @CuentaBancariaID INT = (SELECT TOP 1 CuentaBancariaID FROM #CuentasBancarias ORDER BY NEWID());
        
        DECLARE @Importe DECIMAL(12,2) = @ImporteMin + RAND() * (@ImporteMax - @ImporteMin);
        
        DECLARE @FechaAleatoria DATE = DATEADD(DAY, (RAND() * @DiasRango), @FechaInicio);

        DECLARE @Concepto CHAR(20);

        IF RAND() < @Probabilidad
            SET @Concepto = 'EXTRAORDINARIO';
        ELSE
            SET @Concepto = 'ORDINARIO';

        INSERT INTO contable.Pago 
            (Fecha, CuentaBancariaID, Concepto, Importe)
        VALUES 
            (@FechaAleatoria, @CuentaBancariaID, @Concepto, @Importe);

        SET @i += 1;
    END
    COMMIT TRANSACTION;

    PRINT '============== FIN DE importar.p_GenerarLotePagos ==============';
END
GO


----------------------------------------------------------------------------------------------------------------------------------
    /* Alteracion del SP importar.p_ImportarPagosConsorcios */
----------------------------------------------------------------------------------------------------------------------------------


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
            CuentaBancaria.CuentaBancariaID,
            CTE.Importe
        INTO #PagosLimpio
        FROM CTE
        JOIN persona.CuentaBancaria AS Cuenta
            ON HASHBYTES('SHA2_256', CTE.NroClaveUniforme) = Cuenta.NroClaveUniformeIDHash
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
            CuentaBancariaID,
            Concepto,
            Importe
        )
        SELECT
            Limpio.Fecha,
            Limpio.CuentaBancariaID,
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


----------------------------------------------------------------------------------------------------------------------------------
    /* Alteracion del SP general.p_Reporte1ReacaudacionSemanal */
----------------------------------------------------------------------------------------------------------------------------------

-- REPORTE 1
CREATE OR ALTER PROCEDURE general.p_Reporte1ReacaudacionSemanal
(
    @ConsorcioID INT,    -- parametro 1 el consorcio analizar a seleccionar
    @FechaInicio DATE,   -- parametro 2 desde que fecha
    @FechaFin DATE       -- parametro 3 hasta que fecha
)
 AS
 BEGIN
    SET NOCOUNT ON;
    PRINT CHAR(10) + '============== INICIO DE p_Reporte1ReacaudacionSemanal ==============';

    DROP TABLE IF EXISTS #PagosSemanales;

    SELECT 
        YEAR(Pago.Fecha) AS Anio,
        DATEPART(isowk, Pago.Fecha) AS NroSemana,
       -- sumo los importes de los pagos ordinarios y extraordinarios por separado para esa semana
       SUM(CASE WHEN Pago.Concepto = 'ORDINARIO' THEN Pago.Importe ELSE 0 END) AS RecaudacionOrdinaria,
       SUM(CASE WHEN Pago.Concepto = 'EXTRAORDINARIO' THEN Pago.Importe ELSE 0 END) AS RecaudacionExtraordinaria
    INTO #PagosSemanales
    FROM contable.Pago AS Pago
    INNER JOIN
        persona.CuentaBancaria AS CuentaBancaria 
        ON Pago.CuentaBancariaID = CuentaBancaria.CuentaBancariaID
    INNER JOIN 
        infraestructura.UnidadFuncional AS UnidadFuncional
        ON CuentaBancaria.PersonaID = UnidadFuncional.PropietarioID OR
           CuentaBancaria.PersonaID = UnidadFuncional.InquilinoID
    WHERE 
        (Pago.Fecha >= @FechaInicio AND Pago.Fecha <= @FechaFin) AND
        UnidadFuncional.ConsorcioID = @ConsorcioID
    GROUP BY
        YEAR(Pago.Fecha), DATEPART(isowk, Pago.Fecha);

    SELECT 
        PagosSemanales.Anio,
        PagosSemanales.NroSemana,
        PagosSemanales.RecaudacionOrdinaria,
        PagosSemanales.RecaudacionExtraordinaria,
        (PagosSemanales.RecaudacionOrdinaria + PagosSemanales.RecaudacionExtraordinaria) AS TotalSemanal,
        -- calculo el promedio de los pagos semanales
        AVG(PagosSemanales.RecaudacionOrdinaria + PagosSemanales.RecaudacionExtraordinaria) OVER () AS PromedioSemanal,

        -- calculo el acumlado progresivo
        SUM(PagosSemanales.RecaudacionOrdinaria + PagosSemanales.RecaudacionExtraordinaria)
            OVER (ORDER BY PagosSemanales.Anio, PagosSemanales.NroSemana) AS AcumuladoProgresivo
    FROM #PagosSemanales AS PagosSemanales
    ORDER BY 
        PagosSemanales.Anio, PagosSemanales.NroSemana;

    PRINT CHAR(10) + '============== FIN DE p_Reporte1ReacaudacionSemanal ==============';
END
GO


----------------------------------------------------------------------------------------------------------------------------------
    /* Alteracion del SP general.p_ReporteRecaudacionMensualPorDepartamento_XML */
----------------------------------------------------------------------------------------------------------------------------------


-- REPORTE 2
CREATE OR ALTER PROCEDURE general.p_Reporte2RecaudacionMensualPorDepartamento_XML
(
    @ConsorcioID INT = NULL, -- parametro 1, si es NULL se calcula para todos
    @Anio INT, -- parametro 2
    @Mes INT = NULL -- parametro 3, hasta que mes se calculara
)
    AS
     BEGIN
     SET NOCOUNT ON;

    PRINT CHAR(10) + '============== INCIO DE p_Reporte2RecaudacionMensualPorDepartamento_XML ==============';

    DROP TABLE IF EXISTS #DatosFuente;
     ----------------------------------------------------------------------------------------------------------------------------------
        /* BLOQUE GENERAL */
     ----------------------------------------------------------------------------------------------------------------------------------
    DECLARE @FechaInicio DATE; -- desde el 01/01 del anio que se ingreso
    DECLARE @FechaFin DATE;

    IF @Mes IS NULL
    BEGIN 
        SET @FechaInicio = DATEFROMPARTS(@Anio, 1, 1);
        SET @FechaFin  = DATEADD(month, 1, DATEFROMPARTS(@Anio, 12, 1)); -- hasta el primer dia del mes siguiente a MesFin
    END
    ELSE
    BEGIN
        SET @FechaInicio = DATEFROMPARTS(@Anio, @Mes, 1);
        SET @FechaFin  = DATEADD(month, 1, DATEFROMPARTS(@Anio, @Mes, 1)); -- hasta el primer dia del mes siguiente a MesFin
    END
   
     --vincula pagos con consorcios y la unidad funcional
    SELECT
        (Consorcio.NombreDelConsorcio + ' - Piso ' + UnidadFuncional.Piso + ' Depto ' + UnidadFuncional.Departamento) AS UnidadFuncionalNombre,
        MONTH(Pago.Fecha) AS Mes,
        Pago.Importe
    INTO #DatosFuente
    FROM contable.Pago AS Pago
    INNER JOIN
    persona.CuentaBancaria AS CuentaBancaria
        ON Pago.CuentaBancariaID = CuentaBancaria.CuentaBancariaID
    INNER JOIN
    infraestructura.UnidadFuncional AS UnidadFuncional
        ON CuentaBancaria.PersonaID = UnidadFuncional.PropietarioID OR
    CuentaBancaria.PersonaID = UnidadFuncional.InquilinoID
    INNER JOIN
    infraestructura.Consorcio AS Consorcio
        ON UnidadFuncional.ConsorcioID = Consorcio.ConsorcioID
    WHERE
        (Pago.Fecha >= @FechaInicio AND Pago.Fecha < @FechaFin) AND -- filtro de anio y mes
        (@ConsorcioID IS NULL OR Consorcio.ConsorcioID = @ConsorcioID) -- filtro de consorcio 


    IF @Mes IS NULL
    BEGIN 
        SELECT
            UnidadFuncionalNombre,
                ISNULL([1], 0.00) AS Enero,
                ISNULL([2], 0.00) AS Febrero,
                ISNULL([3], 0.00) AS Marzo,
                ISNULL([4], 0.00) AS Abril,
                ISNULL([5], 0.00) AS Mayo,
                ISNULL([6], 0.00) AS Junio,
                ISNULL([7], 0.00) AS Julio,
                ISNULL([8], 0.00) AS Agosto,
                ISNULL([9], 0.00) AS Septiembre,
                ISNULL([10], 0.00) AS Octubre,
                ISNULL([11], 0.00) AS Noviembre,
                ISNULL([12], 0.00) AS Diciembre
         FROM #DatosFuente
         PIVOT (
             SUM(Importe)
            FOR Mes IN ([1], [2], [3], [4], [5], [6], [7], [8], [9], [10], [11], [12]) -- columnas a crear
        ) AS PagosUFPorMes
         ORDER BY 
              UnidadFuncionalNombre
        
        FOR XML PATH('RecaudacionMensualPorUF'), ROOT('Reporte2RecaudacionMensualPorDepartamento');
    END
    ELSE
    BEGIN
        SELECT 
            UnidadFuncionalNombre,
            SUM(ISNULL(Importe, 0.00)) AS MesSolicitado
        FROM #DatosFuente
        GROUP BY
            UnidadFuncionalNombre
        ORDER BY
            UnidadFuncionalNombre
        
        FOR XML PATH('RecaudacionMensualPorUF'), ROOT('Reporte2RecaudacionMensualPorDepartamento');

    END

    PRINT CHAR(10) + '============== FIN DE p_Reporte2RecaudacionMensualPorDepartamento_XML ==============';
END
GO


----------------------------------------------------------------------------------------------------------------------------------
    /* Alteracion del SP general.p_Reporte3RecaudacionTotalSegunProcedencia */
----------------------------------------------------------------------------------------------------------------------------------


-- REPORTE 3
CREATE OR ALTER PROCEDURE general.p_Reporte3RecaudacionTotalSegunProcedencia
(              
    @ConsorcioID INT,       -- parametro 1, para que consorcionse quiere calcular
    @FechaInicio DATE,      -- parametro 2
    @FechaFin DATE          -- parametro 3
)
AS
BEGIN
    SET NOCOUNT ON;

PRINT CHAR(10) + '============== INCIO DE p_Reporte3RecaudacionTotalSegunProcedencia ==============';

    DROP TABLE IF EXISTS #RecaudacionPorConcepto;

    SELECT 
        YEAR(Pago.Fecha) AS Anio,
        MONTH(Pago.Fecha) AS Mes,
        Pago.Concepto,
        SUM(Pago.Importe) AS TotalRecaudado
    INTO #RecaudacionPorConcepto
    FROM contable.Pago AS Pago
    INNER JOIN persona.CuentaBancaria AS CuentaBancaria
        ON Pago.CuentaBancariaID = CuentaBancaria.CuentaBancariaID
    INNER JOIN infraestructura.UnidadFuncional AS UnidadFuncional
        ON CuentaBancaria.PersonaID = UnidadFuncional.PropietarioID OR
           CuentaBancaria.PersonaID = UnidadFuncional.InquilinoID
    WHERE 
        (Pago.Fecha >= @FechaInicio AND Pago.Fecha <= @FechaFin) AND
        UnidadFuncional.ConsorcioID = @ConsorcioID
    GROUP BY 
        YEAR(Pago.Fecha),
        MONTH(Pago.Fecha),
        Pago.Concepto;

    SELECT 
        Anio, 
        Mes,
        -- columnas para cada concepto 
        SUM(CASE WHEN Concepto = 'ORDINARIO' THEN TotalRecaudado ELSE 0 END) AS TotalOrdinario,
        SUM(CASE WHEN Concepto = 'EXTRAORDINARIO' THEN TotalRecaudado ELSE 0 END) AS TotalExtraordinario,
        -- columna de total general por periodo
        ISNULL(SUM(TotalRecaudado), 0) AS TotalGeneralMes
    FROM #RecaudacionPorConcepto
    GROUP BY Anio, Mes
    ORDER BY Anio,Mes
    FOR XML PATH('RecaudacionTotal'), ROOT('Reporte3RecaudacionTotalSegunProcedencia');

    PRINT CHAR(10) + '============== FIN DE p_Reporte3RecaudacionTotalSegunProcedencia ==============';
END
GO


----------------------------------------------------------------------------------------------------------------------------------
    /* Alteracion del SP general.p_Reporte4MayoresGastosEIngresos */
----------------------------------------------------------------------------------------------------------------------------------


-- REPORTE 4
CREATE OR ALTER PROCEDURE general.p_Reporte4MayoresGastosEIngresos
(
    @ConsorcioID INT,    -- parametro 1 el consorcio a analizar 
    @FechaInicio DATE,   -- parametro 2 desde que fecha
    @FechaFin DATE      -- parametro 3 hasta que fecha
)
 AS
   BEGIN
    SET NOCOUNT ON;

    PRINT CHAR(10) + '============== INCIO DE p_Reporte4MayoresGastosEIngresos ==============';
    DROP TABLE IF EXISTS #IngresosMensuales; 

        SELECT 
            YEAR(Pago.Fecha) AS Anio,
            MONTH(Pago.Fecha) AS Mes,
            SUM(Pago.Importe) AS TotalIngresos
        INTO #IngresosMensuales 
        FROM
            contable.Pago AS Pago
        INNER JOIN
            persona.CuentaBancaria AS CuentaBancaria
            ON Pago.CuentaBancariaID = CuentaBancaria.CuentaBancariaID
        INNER JOIN
            infraestructura.UnidadFuncional AS UnidadFuncional
            ON CuentaBancaria.PersonaID = UnidadFuncional.PropietarioID OR
                CuentaBancaria.PersonaID = UnidadFuncional.InquilinoID
        WHERE
            (Pago.Fecha >= @FechaInicio AND Pago.Fecha <= @FechaFin) AND 
            (UnidadFuncional.ConsorcioID = @ConsorcioID) 
        GROUP BY
            YEAR(Pago.Fecha), MONTH(Pago.Fecha);


    WITH GastosMensualesCTE AS (
        SELECT Anio, MesNro, SUM(TotalGastos) AS TotalGastos
        FROM (
           SELECT
               YEAR(Periodo) AS Anio,
               MONTH(Periodo) AS MesNro,
               SUM(Importe) AS TotalGastos
           FROM contable.GastoOrdinario
           WHERE
               (Periodo >= @FechaInicio AND Periodo <= @FechaFin) AND
               (ConsorcioID = @ConsorcioID)
           GROUP BY
                YEAR(Periodo), MONTH(Periodo)
            
           UNION ALL   
           
           SELECT -- Gastos Extraordinarios
               YEAR(Periodo) AS Anio,
               MONTH(Periodo) AS MesNro,
               SUM(Importe) AS TotalGastos
           FROM contable.GastoExtraordinario
           WHERE
               (Periodo >= @FechaInicio AND Periodo <= @FechaFin) AND
               (ConsorcioID = @ConsorcioID)
           GROUP BY
               YEAR(Periodo), MONTH(Periodo)) AS GastosUnificados
           GROUP BY
            Anio, MesNro
          )

    -- 5 meses de mayores gastos
    SELECT TOP 5  Anio,
        CASE MesNro
            WHEN 1 THEN 'Enero' WHEN 2 THEN 'Febrero' WHEN 3 THEN 'Marzo'
            WHEN 4 THEN 'Abril' WHEN 5 THEN 'Mayo' WHEN 6 THEN 'Junio'
            WHEN 7 THEN 'Julio' WHEN 8 THEN 'Agosto' WHEN 9 THEN 'Septiembre'
            WHEN 10 THEN 'Octubre' WHEN 11 THEN 'Noviembre' WHEN 12 THEN 'Diciembre'
        END AS Mes, TotalGastos        
    FROM GastosMensualesCTE                
    ORDER BY TotalGastos DESC;               

    -- 5 meses de mayores ingresos  
    SELECT TOP 5 Anio,            
        CASE Mes
            WHEN 1 THEN 'Enero' WHEN 2 THEN 'Febrero' WHEN 3 THEN 'Marzo'
            WHEN 4 THEN 'Abril' WHEN 5 THEN 'Mayo' WHEN 6 THEN 'Junio'
            WHEN 7 THEN 'Julio' WHEN 8 THEN 'Agosto' WHEN 9 THEN 'Septiembre'
            WHEN 10 THEN 'Octubre' WHEN 11 THEN 'Noviembre' WHEN 12 THEN 'Diciembre'
         END AS Mes, TotalIngresos
    FROM  #IngresosMensuales
    ORDER BY TotalIngresos DESC;

    PRINT CHAR(10) + '============== FIN DE p_Reporte4MayoresGastosEIngresos ==============';

END
GO


----------------------------------------------------------------------------------------------------------------------------------
    /* Alteracion del SP general.p_Reporte5PropietariosMorosos */
----------------------------------------------------------------------------------------------------------------------------------


-- REPORTE 5
CREATE OR ALTER PROCEDURE general.p_Reporte5PropietariosMorosos
(
    @ConsorcioID INT,    -- parametro 1 el consorcio analizar a seleccionar
    @FechaInicio DATE,   -- parametro 2 desde que fecha
    @FechaFin DATE,      -- parametro 3 hasta que fecha
    @MontoMinimoDeuda DECIMAL (10,2) = NULL  -- parametro opcional, si se quisiera filtrar a partir de un minimo de deuda
)
   AS
   BEGIN
    SET NOCOUNT ON;

    PRINT CHAR(10) + '============== INCIO DE p_Reporte5PropietariosMorosos ==============';

    DROP TABLE IF EXISTS #DeudaPorPropietario;
    
    -- calculo la deuda total acumlada para cada propietario en un consorcio en un rango de fechas
    SELECT
        Persona.PersonaID,
        SUM(Prorrateo.SaldoActual) AS SaldoNetoAcumulado
    INTO #DeudaPorPropietario 
    FROM contable.Prorrateo AS Prorrateo
    INNER JOIN persona.Persona AS Persona 
        ON Prorrateo.PersonaID = Persona.PersonaID
    WHERE 
        Prorrateo.ConsorcioID = @ConsorcioID AND
        (Prorrateo.Periodo >= @FechaInicio AND Prorrateo.Periodo <= @FechaFin)
        AND Persona.EsPropietario = 1 -- para asegurarse de que se este filtrando por propietario
    GROUP BY 
        Persona.PersonaID
    HAVING -- si se ingresa el parametro de monto minimo se filtra tambien por ese valor
        (@MontoMinimoDeuda IS NULL AND SUM(Prorrateo.SaldoActual) > 0) OR -- SUM(Prorrateo.SaldoActual) > 0 significa que debe dinero
        (SUM(Prorrateo.SaldoActual) >= @MontoMinimoDeuda); -- si agregamos un monto minimo, necesitamos comparar contra ese valor
    
    OPEN SYMMETRIC KEY KeyPersonas
    DECRYPTION BY CERTIFICATE CertificadoPersonas;

    SELECT TOP 3 -- busco a los 3 primeros y obtengo su informacion de contacto
        CAST(DECRYPTBYKEY(Persona.DNI) AS VARCHAR(20)) AS DNI,
        CAST(DECRYPTBYKEY(Persona.Nombre) AS VARCHAR(128)) AS Nombre,
        CAST(DECRYPTBYKEY(Persona.Apellido) AS VARCHAR(128)) AS Apellido,
        CAST(DECRYPTBYKEY(Persona.Mail) AS VARCHAR(255)) AS Mail,
        CAST(DECRYPTBYKEY(Persona.Telefono) AS VARCHAR(20)) AS Telefono,
        DeudaPorPropietario.SaldoNetoAcumulado
    FROM #DeudaPorPropietario AS DeudaPorPropietario
    INNER JOIN persona.Persona AS Persona
        ON DeudaPorPropietario.PersonaID = Persona.PersonaID
    ORDER BY
        DeudaPorPropietario.SaldoNetoAcumulado DESC;

    CLOSE SYMMETRIC KEY KeyPersonas;

    PRINT CHAR(10) + '============== FIN DE p_Reporte5PropietariosMorosos ==============';

END
GO


----------------------------------------------------------------------------------------------------------------------------------
    /* Alteracion del SP general.p_Reporte6PagosEntreFechas */
----------------------------------------------------------------------------------------------------------------------------------


-- REPORTE 6
CREATE OR ALTER PROCEDURE general.p_Reporte6PagosEntreFechas
(
    @ConsorcioID INT,    -- parametro 1 el consorcio analizar a seleccionar
    @FechaInicio DATE,   -- parametro 2 desde que fecha
    @FechaFin DATE       -- parametro 3 hasta que fecha
)
   AS
   BEGIN
    SET NOCOUNT ON;

    PRINT CHAR(10) + '============== INCIO DE p_Reporte6PagosEntreFechas ==============';

    WITH PagosOrdinariosUF AS(
        SELECT 
            (Consorcio.NombreDelConsorcio + '- Piso' + UnidadFuncional.Piso + ' - Depto' + UnidadFuncional.Departamento) AS UnidadFuncionalNombre,
            Pago.Fecha AS FechaDePago,
            Pago.Importe
        FROM contable.Pago AS Pago           
        INNER JOIN 
            persona.CuentaBancaria AS CuentaBancaria
            ON Pago.CuentaBancariaID = CuentaBancaria.CuentaBancariaID
        INNER JOIN
            infraestructura.UnidadFuncional AS UnidadFuncional
            ON CuentaBancaria.PersonaID = UnidadFuncional.PropietarioID OR
                CuentaBancaria.PersonaID = UnidadFuncional.InquilinoID
        INNER JOIN
            infraestructura.Consorcio AS Consorcio
            ON UnidadFuncional.ConsorcioID = Consorcio.ConsorcioID

        WHERE
            (Pago.Fecha >= @FechaInicio AND Pago.Fecha <= @FechaFin)
            AND Consorcio.ConsorcioID = @ConsorcioID

        ),

        PagosConSiguiente AS (
        SELECT
            UnidadFuncionalNombre,
            FechaDePago,
            Importe,
            LEAD(FechaDePago, 1) OVER (PARTITION BY UnidadFuncionalNombre 
                                        ORDER BY FechaDePago) AS FechaSiguientePago
        FROM PagosOrdinariosUF        
        )

    SELECT 
        UnidadFuncionalNombre,
        CONVERT(VARCHAR(10), FechaDePago, 103) AS FechaDePago,
        Importe,
        CONVERT(VARCHAR(10), FechaSiguientePago, 103) AS FechaSiguientePago,
        
        -- calcula la cantidad de dias entre las fechas de pago
        DATEDIFF(DAY, FechaDePago, FechaSiguientePago) AS DiasHastaSiguientePago
    FROM PagosConSiguiente      
    ORDER BY UnidadFuncionalNombre, FechaDePago; -- ordenado por fecha de pago
       
    PRINT CHAR(10) + '============== FIN DE p_Reporte6PagosEntreFechas ==============';
END
GO


----------------------------------------------------------------------------------------------------------------------------------
    /* Alteracion del SP importar.p_GenerarGastosExtraordinariosDesdePagos */
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
            DATEFROMPARTS(YEAR(Pago.Fecha), MONTH(Pago.Fecha), 1) AS Periodo,
            Pago.Importe
        FROM contable.Pago AS Pago
        JOIN persona.CuentaBancaria AS CuentaBancaria 
            ON Pago.CuentaBancariaID = CuentaBancaria.CuentaBancariaID
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
    /* Alteracion del SP importar.p_CalcularEstadoFinanciero */
----------------------------------------------------------------------------------------------------------------------------------



CREATE OR ALTER PROCEDURE contable.p_CalcularEstadoFinanciero
    @Periodo DATE -- debe ser el primer dia del mes
AS
BEGIN
    SET NOCOUNT ON;

    PRINT CHAR(10) + '============== INCIO DE p_CalcularEstadoFinanciero ==============';
    SET NOCOUNT ON;

    DECLARE @PeriodoFin DATE = EOMONTH(@Periodo);
    DROP TABLE IF EXISTS #EstadosFinancieros;

    WITH SaldosAnteriores AS (
        SELECT -- seleccionamos el saldo de los estados financieros anteriores para todos los consorcios
            Consorcio.ConsorcioID,
            ISNULL(EstadoFinanciero.SaldoCierre, 0) AS SaldoAnterior
        FROM infraestructura.Consorcio AS Consorcio
        LEFT JOIN contable.EstadoFinanciero AS EstadoFinanciero
            ON Consorcio.ConsorcioID = EstadoFinanciero.ConsorcioID
            AND EstadoFinanciero.Periodo = DATEADD(month, -1, @Periodo) -- restamos un mes al periodo
    ),
    Egresos AS ( -- sumamos para cada consorcio el total de gastos
        SELECT ConsorcioID, SUM(Importe) AS TotalEgresos
        FROM ( -- seleccionamos tanto los gastos ordinarios como los extraordinarios para el mismo periodo
            SELECT ConsorcioID, Importe FROM contable.GastoOrdinario WHERE Periodo = @Periodo
            UNION ALL
            SELECT ConsorcioID, Importe FROM contable.GastoExtraordinario WHERE Periodo = @Periodo
        )AS GastosOrdYExtraord
        GROUP BY ConsorcioID -- agrupamos por consorcio
    ),
    Pagos AS (
        SELECT -- para cada consorcio agrupamos los pagos que recibio en este periodo como en termino o adeudados
            UnidadFuncional.ConsorcioID,
            ISNULL(SUM(CASE WHEN DAY(Pago.Fecha) <= 10 THEN Pago.Importe ELSE 0 END), 0) AS PagoEnTermino,
            ISNULL(SUM(CASE WHEN DAY(Pago.Fecha) > 10 THEN Pago.Importe ELSE 0 END), 0) AS PagoAdeudados -- son adeudadosn si son posteriores al primer vencimiento
        FROM contable.Pago AS Pago
        JOIN persona.CuentaBancaria AS CuentaBancaria
            ON Pago.CuentaBancariaID = CuentaBancaria.CuentaBancariaID
        JOIN infraestructura.UnidadFuncional AS UnidadFuncional
            ON CuentaBancaria.PersonaID = UnidadFuncional.PropietarioID OR
            CuentaBancaria.PersonaID = UnidadFuncional.InquilinoID
        WHERE
            Pago.Fecha BETWEEN @Periodo AND @PeriodoFin -- pagos entre el primer dia y el ultimo dia para el periodo dado
        GROUP BY
            UnidadFuncional.ConsorcioID
    )
    SELECT -- agrupamos para generar el estado financiero en limpio
        SaldosAnteriores.ConsorcioID,
        SaldosAnteriores.SaldoAnterior,
        ISNULL(Egresos.TotalEgresos, 0) AS EgresosPorGastos,
        ISNULL(Pagos.PagoEnTermino, 0) AS PagoEnTermino,
        ISNULL(Pagos.PagoAdeudados, 0) AS PagoAdeudado,
        0.00 AS PagosAdelantados
    INTO #EstadosFinancieros
    FROM SaldosAnteriores
    LEFT JOIN Egresos
        ON SaldosAnteriores.ConsorcioID = Egresos.ConsorcioID
    LEFT JOIN Pagos
        ON SaldosAnteriores.ConsorcioID = Pagos.ConsorcioID;

    UPDATE EstadoFinanciero
    SET
        EstadoFinanciero.SaldoAnterior = #EstadosFinancieros.SaldoAnterior,
        EstadoFinanciero.PagosEnTermino = #EstadosFinancieros.PagoEnTermino,
        EstadoFinanciero.PagosAdeudados = #EstadosFinancieros.PagoAdeudado,
        EstadoFinanciero.PagosAdelantados = #EstadosFinancieros.PagosAdelantados,
        EstadoFinanciero.EgresosPorGastos = #EstadosFinancieros.EgresosPorGastos
    FROM contable.EstadoFinanciero EstadoFinanciero
    JOIN #EstadosFinancieros
        ON EstadoFinanciero.ConsorcioID = #EstadosFinancieros.ConsorcioID
    WHERE EstadoFinanciero.Periodo = @Periodo; -- actualizamos estados financiers anteriores, ya insertados, por si hubo cambios

    INSERT INTO contable.EstadoFinanciero ( -- insertamos el nuevo estado financiero
        ConsorcioID, 
        Periodo, 
        SaldoAnterior, 
        PagosEnTermino, 
        PagosAdeudados, 
        PagosAdelantados, 
        EgresosPorGastos
    )
    SELECT 
        #EstadosFinancieros.ConsorcioID,
        @Periodo,
        #EstadosFinancieros.SaldoAnterior,
        #EstadosFinancieros.PagoEnTermino,
        #EstadosFinancieros.PagoAdeudado,
        #EstadosFinancieros.PagosAdelantados,
        #EstadosFinancieros.EgresosPorGastos
    FROM #EstadosFinancieros
    WHERE NOT EXISTS (
        SELECT 1 
        FROM contable.EstadoFinanciero EstadoFinanciero
        WHERE
            EstadoFinanciero.ConsorcioID = #EstadosFinancieros.ConsorcioID -- siempre que el estado financiero no se repita
            AND EstadoFinanciero.Periodo = @Periodo -- para el mismo consorcio y periodo
    );

    PRINT CHAR(10) + '============== FIN DE p_CalcularEstadoFinanciero ==============';
END
GO


----------------------------------------------------------------------------------------------------------------------------------
	/* Alteracion del SP contable.p_CalcularProrrateoMensual */
----------------------------------------------------------------------------------------------------------------------------------


CREATE OR ALTER PROCEDURE contable.p_CalcularProrrateoMensual
    @Periodo DATE -- debe ser el primer dia del mes
AS
BEGIN
    SET NOCOUNT ON;

    PRINT CHAR(10) + '============== INCIO DE p_CalcularProrrateoMensual ==============';

    DROP TABLE IF EXISTS #DatosCalculados;

    DECLARE @PeriodoFin DATE = EOMONTH(@Periodo);

    SELECT
        Consorcio.ConsorcioID,
        ISNULL(Consorcio.Superficie, 0) AS SuperficieTotalConsorcio,
        ISNULL(LeftJoinConsorcio.GastoOrdTotal, 0) AS GastoOrdTotal,
        ISNULL(LeftJoinGastoExtraord.GastoExtraordTotal, 0) AS GastoExtraordTotal
    INTO #TotalesConsorcio
    FROM infraestructura.Consorcio AS Consorcio
    LEFT JOIN (
        SELECT ConsorcioID, SUM(Importe) AS GastoOrdTotal
        FROM contable.GastoOrdinario
        WHERE Periodo = @Periodo
        GROUP BY ConsorcioID
    ) AS LeftJoinConsorcio ON Consorcio.ConsorcioID = LeftJoinConsorcio.ConsorcioID
    LEFT JOIN (
        SELECT ConsorcioID, SUM(Importe) AS GastoExtraordTotal
        FROM contable.GastoExtraordinario
        WHERE Periodo = @Periodo
        GROUP BY ConsorcioID
    ) AS LeftJoinGastoExtraord ON Consorcio.ConsorcioID = LeftJoinGastoExtraord.ConsorcioID;

    CREATE TABLE #DatosCalculados (
        ConsorcioID INT NOT NULL,
        NroUnidadFuncionalID INT,
        PersonaID INT NOT NULL,
        CuentaBancariaID INT NOT NULL,
        SuperficieTotal DECIMAL(10,2) NOT NULL,
        PorcentajeM2 DECIMAL(3,1) NOT NULL,
        ExpOrd DECIMAL(12,2) NOT NULL,
        ExpExtraOrd DECIMAL(12,2) NOT NULL,
        PagosRecibidos DECIMAL(12,2) NOT NULL,
        FormaEnvioPropietario VARCHAR(20) NOT NULL,
        FormaEnvioInquilino VARCHAR(20),
        PRIMARY KEY (ConsorcioID, NroUnidadFuncionalID)
    );

    DECLARE @PrimerDiaMesSiguiente DATE = DATEADD(month, 1, @Periodo); -- consideramos que se envia la expensa del mes anterior a pagar este mes

    OPEN SYMMETRIC KEY KeyPersonas
    DECRYPTION BY CERTIFICATE CertificadoPersonas;

    INSERT INTO #DatosCalculados (
        ConsorcioID,
        NroUnidadFuncionalID, 
        PersonaID, 
        CuentaBancariaID, 
        SuperficieTotal, 
        PorcentajeM2, 
        ExpOrd, 
        ExpExtraOrd, 
        PagosRecibidos, 
        FormaEnvioPropietario, 
        FormaEnvioInquilino
    )
    SELECT
        UnidadFuncional.ConsorcioID,
        UnidadFuncional.NroUnidadFuncionalID,
        UnidadFuncional.PropietarioID,
        UnidadFuncional.CuentaBancariaID,
        (ISNULL(UnidadFuncional.Superficie, 0) + ISNULL(UnidadFuncional.SuperficieCochera, 0) + ISNULL(UnidadFuncional.SuperficieBaulera, 0)),        
        ((ISNULL(UnidadFuncional.Superficie, 0) + ISNULL(UnidadFuncional.SuperficieCochera, 0) + ISNULL(UnidadFuncional.SuperficieBaulera, 0)) * 100 ) / Totales.SuperficieTotalConsorcio,
        (Totales.GastoOrdTotal * (ISNULL(UnidadFuncional.Superficie, 0) + ISNULL(UnidadFuncional.SuperficieCochera, 0) + ISNULL(UnidadFuncional.SuperficieBaulera, 0)) ) / Totales.SuperficieTotalConsorcio,
        (Totales.GastoExtraordTotal * (ISNULL(UnidadFuncional.Superficie, 0) + ISNULL(UnidadFuncional.SuperficieCochera, 0) + ISNULL(UnidadFuncional.SuperficieBaulera, 0)) ) / Totales.SuperficieTotalConsorcio,

        ISNULL((
            SELECT SUM(Pago.Importe) -- sumamos todos los pagos recibidos que corresponden a esta UnidadFuncional
            FROM contable.Pago Pago
            WHERE Pago.CuentaBancariaID = UnidadFuncional.CuentaBancariaID
            AND Pago.Fecha BETWEEN @Periodo AND @PeriodoFin
        ), 0),

        CASE -- orden de prioridad
            WHEN CAST(DECRYPTBYKEY(Propietario.Mail) AS VARCHAR(255)) IS NOT NULL THEN 'EMAIL'
            WHEN CAST(DECRYPTBYKEY(Propietario.Telefono) AS VARCHAR(20)) IS NOT NULL THEN 'WHATSAPP'
            ELSE 'IMPRESO'
        END, 
        CASE -- tambien vemos si existe un inquilino en la UnidadFuncional
            WHEN UnidadFuncional.InquilinoID IS NULL THEN NULL
            WHEN CAST(DECRYPTBYKEY(Propietario.Mail) AS VARCHAR(255)) IS NOT NULL THEN 'EMAIL'
            WHEN CAST(DECRYPTBYKEY(Propietario.Telefono) AS VARCHAR(20)) IS NOT NULL THEN 'WHATSAPP'
            ELSE 'IMPRESO'
        END

    FROM infraestructura.UnidadFuncional UnidadFuncional
    INNER JOIN #TotalesConsorcio AS Totales
        ON UnidadFuncional.ConsorcioID = Totales.ConsorcioID
    INNER JOIN persona.Persona Propietario -- hacemos join con las perosnas para obtener su telefono y email
        ON UnidadFuncional.PropietarioID = Propietario.PersonaID
    LEFT JOIN persona.Persona Inquilino
        ON UnidadFuncional.InquilinoID = Inquilino.PersonaID
    WHERE Totales.SuperficieTotalConsorcio > 0;

    CLOSE SYMMETRIC KEY KeyPersonas;

    BEGIN TRY
        BEGIN TRANSACTION; -- como vamos a actualizar los prorrateos iniciamos una transaccion

        UPDATE Prorrateo -- actualizamos por si se necesitan regenerar el estado (nuevos pagos, gastos, ect)
        SET
            Prorrateo.ExpOrd = #DatosCalculados.ExpOrd,
            Prorrateo.ExpExtraOrd = #DatosCalculados.ExpExtraOrd,
            Prorrateo.PagosRecibidos = #DatosCalculados.PagosRecibidos,
            Prorrateo.PorcentajePorM2 = #DatosCalculados.PorcentajeM2,
            Prorrateo.FormaEnvioPropietario = #DatosCalculados.FormaEnvioPropietario,
            Prorrateo.FormaEnvioInquilino = #DatosCalculados.FormaEnvioInquilino
        FROM contable.Prorrateo Prorrateo
        INNER JOIN #DatosCalculados
            ON Prorrateo.ConsorcioID = #DatosCalculados.ConsorcioID AND
            Prorrateo.NroUnidadFuncionalID = #DatosCalculados.NroUnidadFuncionalID
        WHERE
            Prorrateo.Periodo = @Periodo;

        WITH ProrrateoAnterior AS ( -- buscamos el prorrateo anterior para insertarlo en el nuevo prorrateo
            SELECT
                ProrrateoAnterior.SaldoActual, 
                ProrrateoAnterior.FechaVencimiento1, 
                ProrrateoAnterior.FechaVencimiento2,
                ProrrateoAnterior.ConsorcioID,
                ProrrateoAnterior.NroUnidadFuncionalID,
                ROW_NUMBER() OVER(
                    PARTITION BY ProrrateoAnterior.ConsorcioID, ProrrateoAnterior.NroUnidadFuncionalID
                    ORDER BY ProrrateoAnterior.Periodo DESC
                ) AS Numero
            FROM contable.Prorrateo ProrrateoAnterior
            WHERE ProrrateoAnterior.Periodo < @Periodo
        )

        INSERT INTO contable.Prorrateo (
            ConsorcioID,
            NroUnidadFuncionalID, 
            PersonaID,
            Periodo,
            FechaVencimiento1,
            FechaVencimiento2,
            PorcentajePorM2,
            ExpOrd, 
            ExpExtraOrd, 
            SaldoAnterior,
            PagosRecibidos,
            InteresPorMora,
            FormaEnvioPropietario,
            FormaEnvioInquilino
        )
        SELECT
            #DatosCalculados.ConsorcioID,
            #DatosCalculados.NroUnidadFuncionalID,
            #DatosCalculados.PersonaID,
            @Periodo,
            DATEADD(day, 10, @PeriodoFin), -- calculamos los vencimientos respectos al periodo dado
            DATEADD(day, 20, @PeriodoFin),
            #DatosCalculados.PorcentajeM2,
            #DatosCalculados.ExpOrd,
            #DatosCalculados.ExpExtraOrd,
            ISNULL(ProrrateoAnterior.SaldoActual, 0.00),
            #DatosCalculados.PagosRecibidos,
            CASE -- lo comparamos con el dia de hoy para saber si esta vencida o no
                WHEN ISNULL(ProrrateoAnterior.SaldoActual, 0.00) > 0 THEN
                    CASE
                        WHEN GETDATE() > ProrrateoAnterior.FechaVencimiento2 THEN ISNULL(ProrrateoAnterior.SaldoActual, 0.00) * 0.05
                        WHEN GETDATE() > ProrrateoAnterior.FechaVencimiento1 THEN ISNULL(ProrrateoAnterior.SaldoActual, 0.00) * 0.02
                        ELSE 0.00 
                    END
                ELSE 0.00
            END,
            #DatosCalculados.FormaEnvioPropietario,
            #DatosCalculados.FormaEnvioInquilino
        FROM #DatosCalculados
        LEFT JOIN ProrrateoAnterior
            ON #DatosCalculados.ConsorcioID = ProrrateoAnterior.ConsorcioID
            AND #DatosCalculados.NroUnidadFuncionalID = ProrrateoAnterior.NroUnidadFuncionalID
            AND ProrrateoAnterior.Numero = 1
        LEFT JOIN contable.Prorrateo AS Prorrateo
            ON #DatosCalculados.NroUnidadFuncionalID = Prorrateo.NroUnidadFuncionalID
            AND Prorrateo.ConsorcioID = #DatosCalculados.ConsorcioID
            AND Prorrateo.Periodo = @Periodo
        WHERE Prorrateo.ProrrateoID IS NULL;

        COMMIT TRANSACTION;
        PRINT CHAR(10) + '============== FIN DE p_CalcularProrrateoMensual ==============';
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH

    DROP TABLE #DatosCalculados;
END
GO

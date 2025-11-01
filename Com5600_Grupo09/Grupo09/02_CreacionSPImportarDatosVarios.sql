/**********************************************************
 * Bases de Datos Aplicada - Comisión 5600
 * GRUPO 09
 *
 * Archivo: 03_CreacionSPImportarInquilinoPropietariosUF.sql
 * Enunciado cumplimentado: Creación del SP para importar 
 * el maestro Datos Varios.xlsx (Consorcios y proveedores)
 *
 * Integrantes:
 * - Ludmila Daiana Ibarra Sánchez DNI 42537300
 * - Gianluca Ferreyra DNI 46026937
 * - Rodrigo Ezequiel Maranzana DNI 41853030
 *********************************************************/

USE Com5600G09;
GO

CREATE OR ALTER PROCEDURE importar.p_ImportarDatosVarios
    @RutaArchivoXLSX VARCHAR(260)
AS
BEGIN
    SET NOCOUNT ON;

    PRINT '-- INCIO DE p_ImportarDatosVarios --';
    
    CREATE TABLE #ConsorciosXLSXTemp (
        NombreDelConsorcio VARCHAR(255) COLLATE Latin1_General_CI_AI,
        Domicilio VARCHAR(255) COLLATE Latin1_General_CI_AI,
        CantidadUnidadesFuncionales INT,
        M2Totales DECIMAL(6,2)
    );

    CREATE TABLE #ProveedoresXLSXTemp (
        Categoria VARCHAR(255) COLLATE Latin1_General_CI_AI,
        RazonSocial VARCHAR(255) COLLATE Latin1_General_CI_AI,
        Detalle VARCHAR(255) COLLATE Latin1_General_CI_AI,
        NombreDelConsorcio VARCHAR(255) COLLATE Latin1_General_CI_AI
    );

    BEGIN TRY

        ----------------------------------------------------------------------------------------------------------------------------------
        /* BLOQUE GENERAL */
        ----------------------------------------------------------------------------------------------------------------------------------

        DECLARE @Conexion NVARCHAR(MAX);
        SET @Conexion = N'''Excel 12.0;Database=' + @RutaArchivoXLSX + ';HDR=YES;IMEX=1''';
        DECLARE @Openrowset NVARCHAR(MAX);

        DECLARE @FilasTotalesExcel INT;;
        DECLARE @FilasInsertadas INT;
        DECLARE @FilasCorruptas INT;
        DECLARE @FilasDuplicadas INT;

        ----------------------------------------------------------------------------------------------------------------------------------
        /* HOJA CONSORCIOS */
        ----------------------------------------------------------------------------------------------------------------------------------

        PRINT CHAR(10) + 'Iniciando el proceso para la hoja de los consorcios';

        SET @Openrowset = 
                N'INSERT INTO #ConsorciosXLSXTemp (NombreDelConsorcio, Domicilio, CantidadUnidadesFuncionales, M2Totales) ' +
                N'SELECT [Nombre del consorcio], [Domicilio], [Cant unidades funcionales], [m2 totales] ' +
                N'FROM OPENROWSET(''Microsoft.ACE.OLEDB.12.0'', ' + @Conexion + N', ''SELECT * FROM [Consorcios$]'')';
        
        EXEC sp_executesql @Openrowset;

        SELECT @FilasTotalesExcel = COUNT(*) FROM #ConsorciosXLSXTemp;
        PRINT 'La hoja de consorcios se cargó en #ConsorciosXLSXTemp.' + CHAR(10) + 'Filas totales: ' + CAST(@FilasTotalesExcel AS VARCHAR(10));


        ----------------------------------------------------------------------------------------------------------------------------------
        /* FILAS CORRUPTAS DEL ARCHIVO XLSX */
        ----------------------------------------------------------------------------------------------------------------------------------

        SELECT @FilasCorruptas = COUNT(*)
        FROM #ConsorciosXLSXTemp
        WHERE (
            NULLIF(LTRIM(RTRIM(#ConsorciosXLSXTemp.NombreDelConsorcio)), '') IS NULL OR
            NULLIF(LTRIM(RTRIM(#ConsorciosXLSXTemp.Domicilio)), '') IS NULL
        );


        ----------------------------------------------------------------------------------------------------------------------------------
        /* UPDATE DE FILAS EXISTENTES */
        ----------------------------------------------------------------------------------------------------------------------------------

        UPDATE Consorcio
        SET
            Consorcio.Domicilio = LTRIM(RTRIM(ConsorcioTemp.Domicilio)),
            Consorcio.CantidadUF = ConsorcioTemp.CantidadUnidadesFuncionales,
            Consorcio.Superficie = ConsorcioTemp.M2Totales
        FROM infraestructura.Consorcio AS Consorcio
        JOIN #ConsorciosXLSXTemp AS ConsorcioTemp
            ON Consorcio.NombreDelConsorcio = LTRIM(RTRIM(ConsorcioTemp.NombreDelConsorcio))
        WHERE (
            Consorcio.Domicilio <> LTRIM(RTRIM(ConsorcioTemp.Domicilio)) OR
            Consorcio.CantidadUF <> ConsorcioTemp.CantidadUnidadesFuncionales OR
            Consorcio.Superficie <> ConsorcioTemp.M2Totales
        )

        ----------------------------------------------------------------------------------------------------------------------------------
        /* INSERT DE FILAS NUEVAS */
        ----------------------------------------------------------------------------------------------------------------------------------

        INSERT INTO infraestructura.Consorcio (NombreDelConsorcio, Domicilio, CantidadUF, Superficie)
        SELECT DISTINCT
            LTRIM(RTRIM(ConsorcioTemp.NombreDelConsorcio)),
            LTRIM(RTRIM(ConsorcioTemp.Domicilio)),
            ISNULL(ConsorcioTemp.CantidadUnidadesFuncionales, 0), -- ponemos 0 para otorgar flexibilidad, ya que puede actualizarse luego
            ISNULL(ConsorcioTemp.M2Totales, 0)                    -- ponemos 0 para otorgar flexibilidad, ya que puede actualizarse luego
        FROM #ConsorciosXLSXTemp AS ConsorcioTemp
        WHERE
            NULLIF(LTRIM(RTRIM(ConsorcioTemp.NombreDelConsorcio)), '') IS NOT NULL AND
            NULLIF(LTRIM(RTRIM(ConsorcioTemp.Domicilio)), '') IS NOT NULL AND
            NOT EXISTS
            ( -- filtra repetidos y aquellos NombreDelConsorcio o Domicilio con celda vacia
                SELECT 1
                FROM infraestructura.Consorcio AS Consorcio
                WHERE Consorcio.NombreDelConsorcio = LTRIM(RTRIM(ConsorcioTemp.NombreDelConsorcio))
            );
        SET @FilasInsertadas = @@ROWCOUNT; -- la cantidad de filas que fueron afectadas por el INSERT
        SET @FilasDuplicadas = @FilasTotalesExcel - @FilasInsertadas - @FilasCorruptas;

        PRINT CHAR(10) + '>>>Importacion de infraestructura.Consorcio completado:'
        PRINT '     Inserciones totales: ' + CAST(@FilasInsertadas AS VARCHAR(10));
        PRINT '     Registros duplicados: ' + CAST(@FilasDuplicadas AS VARCHAR(10));
        PRINT '     Registros corruptas: ' + CAST(@FilasCorruptas AS VARCHAR(10));

        ----------------------------------------------------------------------------------------------------------------------------------


        ----------------------------------------------------------------------------------------------------------------------------------
        /* HOJA PROVEEDORES */
        ----------------------------------------------------------------------------------------------------------------------------------

        PRINT CHAR(10) + 'Iniciando el proceso para la hoja de los proveedores';

        SET @Conexion = N'''Excel 12.0;Database=' + @RutaArchivoXLSX + ';HDR=NO;IMEX=1'''; -- indicamos que no tiene header (HDR=NO)

        SET @Openrowset = 
                     N'INSERT INTO #ProveedoresXLSXTemp (Categoria, RazonSocial, Detalle, NombreDelConsorcio) ' +
                     N'SELECT F1, F2, F3, F4 ' +    -- ignora automaticamente la primer columna vacia de la izquierda, no es necesario empezar en F2
                     N'FROM OPENROWSET(''Microsoft.ACE.OLEDB.12.0'', ' + @Conexion + N', ''SELECT * FROM [Proveedores$B3:E]'')'; -- ignoramos la columna A en blanco y las dos filas iniciales y vamos hasta la columa E
        
        EXEC sp_executesql @Openrowset;

        SELECT @FilasTotalesExcel = COUNT(*) FROM #ProveedoresXLSXTemp;
        PRINT 'La hoja de proveedores se cargó en #ProveedoresXLSXTemp.' + CHAR(10) + 'Filas totales: ' + CAST(@FilasTotalesExcel AS VARCHAR(10));

        ----------------------------------------------------------------------------------------------------------------------------------
        /* REORGANIZACION DE LA TABLA */
        ----------------------------------------------------------------------------------------------------------------------------------

        UPDATE #ProveedoresXLSXTemp
        SET
        Categoria = UPPER(LTRIM(RTRIM(Categoria))),
        NombreDelConsorcio = LTRIM(RTRIM(NombreDelConsorcio));

        UPDATE #ProveedoresXLSXTemp
        SET 
        RazonSocial = UPPER(LTRIM(RTRIM(Detalle))),
        Detalle = LTRIM(RTRIM(RazonSocial))
        WHERE Categoria = 'GASTOS DE LIMPIEZA';

        UPDATE #ProveedoresXLSXTemp
        SET 
        RazonSocial = UPPER(LTRIM(RTRIM(SUBSTRING(#ProveedoresXLSXTemp.RazonSocial, 1, CHARINDEX('-', #ProveedoresXLSXTemp.RazonSocial) - 1)))),
        Detalle = LTRIM(RTRIM(SUBSTRING(#ProveedoresXLSXTemp.RazonSocial,CHARINDEX('-', #ProveedoresXLSXTemp.RazonSocial) + 1,255)))
        WHERE Categoria != 'GASTOS DE LIMPIEZA' AND Categoria != 'SERVICIOS PUBLICOS';

        ----------------------------------------------------------------------------------------------------------------------------------
        /* FILAS CORRUPTAS DEL ARCHIVO XLSX */
        ----------------------------------------------------------------------------------------------------------------------------------

        SELECT @FilasCorruptas = COUNT(*)
        FROM #ProveedoresXLSXTemp
        WHERE (
            NULLIF(#ProveedoresXLSXTemp.Categoria, '') IS NULL OR
            NULLIF(#ProveedoresXLSXTemp.RazonSocial, '') IS NULL OR
            NULLIF(#ProveedoresXLSXTemp.NombreDelConsorcio, '') IS NULL OR

            ((#ProveedoresXLSXTemp.Categoria = 'SERVICIOS PUBLICOS' OR
            #ProveedoresXLSXTemp.Categoria = 'GASTOS DE LIMPIEZA') AND
            NULLIF(#ProveedoresXLSXTemp.Detalle, '') IS NULL)
        );

        ----------------------------------------------------------------------------------------------------------------------------------
        /* UPDATE DE FILAS EXISTENTES */
        ----------------------------------------------------------------------------------------------------------------------------------
            
            /**
                Consideramos que en este caso no hay actualizaciones que puedan venir mediante el archivo,
                tal vez si podrian hacerse actualizaciones masivas luego, con otro SP, por ejemplo del Detalle.
                Nuestro disenio utilza como UNIQUE compuesto al ConsorcioID, RazonSocial y Detalle.
            **/

        ----------------------------------------------------------------------------------------------------------------------------------
        /* INSERT DE FILAS NUEVAS */
        ----------------------------------------------------------------------------------------------------------------------------------

        INSERT INTO persona.Servicio(Detalle, RazonSocial, Categoria, ConsorcioID)
        SELECT DISTINCT
            ProveedoresTemp.Detalle,
            ProveedoresTemp.RazonSocial,
            ProveedoresTemp.Categoria,
            Consorcio.ConsorcioID
        FROM #ProveedoresXLSXTemp AS ProveedoresTemp
        JOIN infraestructura.Consorcio AS Consorcio
            ON ProveedoresTemp.NombreDelConsorcio = Consorcio.NombreDelConsorcio
        WHERE
            NULLIF(ProveedoresTemp.Detalle, '') IS NOT NULL AND
            NULLIF(ProveedoresTemp.RazonSocial, '') IS NOT NULL AND
            NULLIF(ProveedoresTemp.Categoria, '') IS NOT NULL AND
            NOT EXISTS
            ( -- filtra repetidos
                SELECT 1
                FROM persona.Servicio AS Servicio
                WHERE 
                Servicio.ConsorcioID = Consorcio.ConsorcioID AND
                Servicio.RazonSocial = ProveedoresTemp.RazonSocial AND
                Servicio.Detalle = ProveedoresTemp.Detalle
            );
        SET @FilasInsertadas = @@ROWCOUNT; -- la cantidad de filas que fueron afectadas por el INSERT
        SET @FilasDuplicadas = @FilasTotalesExcel - @FilasInsertadas - @FilasCorruptas;

        PRINT CHAR(10) + '>>>Importacion de persona.Servicio completado:'
        PRINT '     Inserciones totales: ' + CAST(@FilasInsertadas AS VARCHAR(10));
        PRINT '     Registros duplicados: ' + CAST(@FilasDuplicadas AS VARCHAR(10));
        PRINT '     Registros corruptas: ' + CAST(@FilasCorruptas AS VARCHAR(10));

    END TRY
    BEGIN CATCH
        
        PRINT 'Error: No se pudo cargar el archivo XLSX';

        -- problemas con microsoft OLEDB o el archivo .xlsx
        DECLARE @ErrorMessage NVARCHAR(4000);
        SELECT @ErrorMessage = ERROR_MESSAGE()
        PRINT @ErrorMessage;
    
    END CATCH

    PRINT CHAR(10) + '-- FIN DE p_ImportarDatosVarios --';

    DROP TABLE IF EXISTS #ConsorciosXLSXTemp;
    DROP TABLE IF EXISTS #ProveedoresXLSXTemp;
    DROP TABLE IF EXISTS #ProveedoresTempFiltrada;

END
GO
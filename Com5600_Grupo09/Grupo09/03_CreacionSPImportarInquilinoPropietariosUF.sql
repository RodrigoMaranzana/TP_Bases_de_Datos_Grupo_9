/**********************************************************
 * Bases de Datos Aplicada - Comisión 5600
 * GRUPO 09
 *
 * Archivo: 03_CreacionSPImportarInquilinoPropietariosUF.sql
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

DROP PROCEDURE IF EXISTS p_ImportarUnidadesFuncionales;
GO

CREATE PROCEDURE p_ImportarUnidadesFuncionales
    @RutaArchivoCSV VARCHAR(260) -- 260 es el limite de ruta de Windows
AS
BEGIN
    SET NOCOUNT ON; -- Suprime los mensajes de inserto de registros

    CREATE TABLE #UnidadFuncionalCSVTemp (
        CVU_CBU VARCHAR(22),
        NombreDelConsorcio VARCHAR(255),
        NroUnidadFuncionalID INT,
        Piso VARCHAR(3),
        Departamento VARCHAR(2)
    );
    
    BEGIN TRY
        PRINT 'Iniciando el proceso de BULK INSERT';

        DECLARE @BulkInsert NVARCHAR(MAX);

        SET @BulkInsert = 
                    N'BULK INSERT #UnidadFuncionalCSVTemp FROM ''' + @RutaArchivoCSV + N''' ' +
                    N'WITH (' +
                    N' FIELDTERMINATOR = ''|'',' +
                    N' ROWTERMINATOR = ''0x0a'',' +
                    N' FIRSTROW = 2,' +              -- Tiene un encabezado en la fila 1
                    N' CODEPAGE = ''65001''' +       -- Notepad++ me indica que el archivo es UTF-8, este es el codepage de UTF-8
                    N');';
        
        EXEC sp_executesql @BulkInsert;

        PRINT 'Archivo CSV cargado correctamente';
        
        -- Deberiamos validar de alguna forma cada columna??

        CREATE TABLE #UnidadFuncionalTempFiltrada (
            NroUnidadFuncionalID INT,             -- Es la PK
            ConsorcioID INT,
            Piso CHAR(2),
            Departamento CHAR(1),
            -- Estos de abajo no estan en el CSV
            Superficie DECIMAL(6,2),
            TieneBaulera BIT,
            -- SuperficieBaulera DECIMAL(6,2),  -- No se necesita porque puede ser NULL
            TieneCochera BIT,
            -- SuperficieCochera DECIMAL(6,2),  -- No se necesita porque puede ser NULL
            Coeficiente DECIMAL(2,1)
        );

        INSERT INTO #UnidadFuncionalTempFiltrada (
            NroUnidadFuncionalID,
            ConsorcioID,
            Piso,
            Departamento,
            Superficie,
            TieneBaulera,
            TieneCochera,
            Coeficiente
        )
        SELECT
            UFCSVTemp.NroUnidadFuncionalID,
            Consorcio.ConsorcioID,
            UFCSVTemp.Piso,
            UFCSVTemp.Departamento,
        
            -- valores por defecto en los que tienen NOT NULL
            1.0 AS Superficie,  -- tiene CHECK > 0
            0 AS TieneBaulera,
            0 AS TieneCochera,
            1.0 AS Coeficiente  -- tiene CHECK > 0
        FROM
            #UnidadFuncionalCSVTemp AS UFCSVTemp
        INNER JOIN
            infraestructura.Consorcio AS Consorcio ON UFCSVTemp.NombreDelConsorcio = Consorcio.NombreConsorcio;

        PRINT 'Registros insertados en UnidadFuncionalTempFiltrada';

        -- DEBUG
        PRINT '--- #UnidadFuncionalCSVTemp ---';
        SELECT * FROM #UnidadFuncionalCSVTemp;

        PRINT '--- #UnidadFuncionalTempFiltrada ---';
        SELECT * FROM #UnidadFuncionalTempFiltrada;
        -- DEBUG


        -- ACA DEBE SEGUIR EL MERGE



    END TRY
    BEGIN CATCH

        PRINT 'Error: No se pudo cargar el archivo CSV';
 
    END CATCH

    PRINT 'Fin del proceso de importacion de las Unidades Funcionales';
    
    DROP TABLE IF EXISTS #UnidadFuncionalCSVTemp;
    DROP TABLE IF EXISTS #UnidadFuncionalTempFiltrada;
END
GO

-- DEBUG
EXEC p_ImportarUnidadesFuncionales 'C:\Users\rodri\Development\Bases_de_Datos_Aplicadas\TP_Bases_de_Datos_Grupo_9\Maestros\Inquilino-propietarios-UF.csv';
GO
-- DEBUG
    
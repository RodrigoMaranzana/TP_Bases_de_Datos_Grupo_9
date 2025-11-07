/**********************************************************
 * Bases de Datos Aplicada - Comisi�n 5600
 * GRUPO 09
 *
 * Archivo: 08_EjecutarSPDeImportacion.sql
 * Enunciado cumplimentado: Creaci�n de script para la importación de maestros
 *
 * Integrantes:
 * - Ludmila Daiana Ibarra Sánchez DNI 42537300
 * - Gianluca Ferreyra DNI 46026937
 * - Rodrigo Ezequiel Maranzana DNI 41853030
 *********************************************************/

USE Com5600G09;
GO

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
        ON Pago.NroClaveUniformeID = CuentaBancaria.NroClaveUniformeID
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
        ON Pago.NroClaveUniformeID = CuentaBancaria.NroClaveUniformeID
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

    PRINT CHAR(10) + '============== FIN DE p_ReporteRecaudacionMensualPorDepartamento_XML ==============';

END
GO


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
        ON Pago.NroClaveUniformeID = CuentaBancaria.NroClaveUniformeID
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
            ON Pago.NroClaveUniformeID = CuentaBancaria.NroClaveUniformeID
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
        SUM(Prorrateo.Total) AS DeudaTotalAcumulada
    INTO #DeudaPorPropietario 
    FROM contable.Prorrateo AS Prorrateo
    INNER JOIN persona.Persona AS Persona 
        ON Prorrateo.PersonaID = Persona.PersonaID
    WHERE 
        Prorrateo.ConsorcioID = @ConsorcioID AND
        (Prorrateo.Periodo >= @FechaInicio AND Prorrateo.Periodo <= @FechaFin) AND
        Persona.EsPropietario = 1 -- para asegurarse de que se este filtrando por propietario
    GROUP BY 
        Persona.PersonaID
    HAVING -- si se ingresa el parametro de monto minimo se filtra tambien por ese valor
        (@MontoMinimoDeuda IS NULL OR SUM(Prorrateo.Total) >= @MontoMinimoDeuda);
    
    SELECT TOP 3 -- busco a los 3 primeros y obtengo su informacion de contacto
        Persona.DNI,
        Persona.Nombre,
        Persona.Apellido,
        Persona.Mail,
        Persona.Telefono,
        DeudaPorPropietario.DeudaTotalAcumulada
    FROM #DeudaPorPropietario AS DeudaPorPropietario
    INNER JOIN persona.Persona AS Persona
        ON DeudaPorPropietario.PersonaID = Persona.PersonaID
    ORDER BY
        DeudaPorPropietario.DeudaTotalAcumulada DESC;

    PRINT CHAR(10) + '============== FIN DE p_Reporte5PropietariosMorosos ==============';

END
GO


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
            ON Pago.NroClaveUniformeID = CuentaBancaria.NroClaveUniformeID
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

-- REPORTE 7 con API quickchart.io para generacion de graficos
CREATE OR ALTER PROCEDURE general.p_Reporte7GraficoDeGastosOrdinariosPorCategoria
(
    @ConsorcioID INT,
    @PeriodoAnio INT,
    @PeriodoMes INT
)
AS
BEGIN
    SET NOCOUNT ON;

    PRINT CHAR(10) + '============== INCIO DE p_Reporte7GraficoDeGastosOrdinariosPorCategoria ==============';

    DROP TABLE IF EXISTS  #GastoOrdinarioQuickchart;

    DECLARE @FechaInicio DATE = DATEFROMPARTS(@PeriodoAnio, @PeriodoMes, 1); -- calculamos el DATE
    DECLARE @FechaFin DATE = EOMONTH(@FechaInicio); -- nos da la ultima fecha del mes (end of month)
    DECLARE @Json VARCHAR(MAX); -- aca pondremos el json a enviar por URL
    DECLARE @GastoTotal DECIMAL(12, 2);
    DECLARE @Labels VARCHAR(MAX); -- estos son las etiquetas a colocar por color del grafico
    DECLARE @Importes VARCHAR(MAX); -- grupo de importes por categoria
    DECLARE @Url VARCHAR(MAX);
    DECLARE @NombreConsorcio VARCHAR(255);
    
    SELECT @GastoTotal = SUM(Importe) --gasto total para saber nuestro total sobre el cual promediar
    FROM contable.GastoOrdinario
    WHERE ConsorcioID = @ConsorcioID
      AND Periodo BETWEEN @FechaInicio AND @FechaFin;

    SELECT @NombreConsorcio = Consorcio.NombreDelConsorcio
    FROM infraestructura.Consorcio AS Consorcio
    WHERE ConsorcioID = @ConsorcioID;

    IF @GastoTotal IS NULL OR @GastoTotal = 0
    BEGIN
         RETURN;
    END

    SELECT --gasto por categoria
        GastoOrdinario.Categoria,
        SUM(GastoOrdinario.Importe) AS Importe
    INTO #GastoOrdinarioQuickchart
    FROM contable.GastoOrdinario AS GastoOrdinario
    WHERE
        GastoOrdinario.ConsorcioID = @ConsorcioID
        AND GastoOrdinario.Periodo BETWEEN @FechaInicio AND @FechaFin -- entre la fecha dada y la actual
    GROUP BY
        GastoOrdinario.Categoria

    SELECT @Labels = (SELECT Categoria FROM #GastoOrdinarioQuickchart FOR JSON PATH); -- seleccionamos las categorias para usarlas como labels en la url
    -- limpiamos los nombres de las columnas
    SET @Labels = REPLACE(@Labels, '{"Categoria":"', '"');
    SET @Labels = REPLACE(@Labels, '"}', '"');
    
    -- limpiamos los nombres de las columnas
    SELECT @Importes = (SELECT Importe FROM #GastoOrdinarioQuickchart FOR JSON PATH);
    SET @Importes = REPLACE(@Importes, '{"Importe":', '');
    SET @Importes = REPLACE(@Importes, '}', '');

    -- ejemplo en la documentacion: quickchart.io/sandbox#%7B%0A%20%20type%3A%20%27doughnut%27%2C%0A%20%20data%3A%20%7B%0A%20%20%20%20datasets%3A%20%5B%0A%20%20%20%20%20%20%7B%0A%20%20%20%20%20%20%20%20data%3A%20%5B94%2C%2025%2C%2072%2C%2070%2C%2014%5D%2C%0A%20%20%20%20%20%20%20%20backgroundColor%3A%20%5B%0A%20%20%20%20%20%20%20%20%20%20%27rgb(255%2C%2099%2C%20132)%27%2C%0A%20%20%20%20%20%20%20%20%20%20%27rgb(255%2C%20159%2C%2064)%27%2C%0A%20%20%20%20%20%20%20%20%20%20%27rgb(255%2C%20205%2C%2086)%27%2C%0A%20%20%20%20%20%20%20%20%20%20%27rgb(75%2C%20192%2C%20192)%27%2C%0A%20%20%20%20%20%20%20%20%20%20%27rgb(54%2C%20162%2C%20235)%27%2C%0A%20%20%20%20%20%20%20%20%5D%2C%0A%20%20%20%20%20%20%20%20label%3A%20%27Dataset%201%27%2C%0A%20%20%20%20%20%20%7D%2C%0A%20%20%20%20%5D%2C%0A%20%20%20%20labels%3A%20%5B%27Red%27%2C%20%27Orange%27%2C%20%27Yellow%27%2C%20%27Green%27%2C%20%27Blue%27%5D%2C%0A%20%20%7D%2C%0A%20%20options%3A%20%7B%0A%20%20%20%20title%3A%20%7B%0A%20%20%20%20%20%20display%3A%20true%2C%0A%20%20%20%20%20%20text%3A%20%27Chart.js%20Doughnut%20Chart%27%2C%0A%20%20%20%20%7D%2C%0A%20%20%7D%2C%0A%7D%0A
    -- creamos el json a enviar por la url
    SET @Json = 
        N'{"type":"doughnut","data":{"labels":' + @Labels + ',' +
        '"datasets":[{"label":"Gastos Ordinarios","data":' + @Importes + ',' +
        '"backgroundColor":["rgb(54, 162, 235)","rgb(230, 32, 0)","rgb(42, 205, 86)","rgb(255, 159, 64)","rgb(255, 200, 32)"]}]},' +
        'options:{title:{display:true,text:"Distribucion de Gastos Ordinarios por Categoria - Consorcio: ' + @NombreConsorcio + ' - Mes: ' + TRY_CAST(@PeriodoMes AS VARCHAR(2))  +  ' Año: ' + TRY_CAST(@PeriodoAnio AS VARCHAR(4)) + '"}}}';
        
    SET @Url = 'https://quickchart.io/chart?c=' + @Json + N'&width=512&height=512';

    SELECT 
        @Url AS URLQuickChart; --mostrar el resultado

    PRINT CHAR(10) + '============== FIN DE p_Reporte7GraficoDeGastosOrdinariosPorCategoria ==============';
END
GO
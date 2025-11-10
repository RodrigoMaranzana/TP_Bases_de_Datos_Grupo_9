/**********************************************************
 * Bases de Datos Aplicada - Comisión 5600
 * GRUPO 09
 *
 * Archivo: 01_CreacionObjetos.sql
 * Enunciado cumplimentado: Creación de los objetos el proyecto.
 *
 * Integrantes:
 * - Ludmila Daiana Ibarra Sánchez DNI 42537300
 * - Gianluca Ferreyra DNI 46026937
 * - Rodrigo Ezequiel Maranzana DNI 41853030
 *********************************************************/


/**********************************************************
* 
*				   INICIO DE LA SOLUCION 
*
**********************************************************/


USE Com5600G09;
GO

----------------------------------------------------------------------------------------------------------------------------------
	/* ELIMINACION DE TABLAS */
----------------------------------------------------------------------------------------------------------------------------------

-- las eliminamos en el orden correcto para que no queden dependencias
DROP TABLE IF EXISTS contable.Prorrateo;
GO
DROP TABLE IF EXISTS contable.EstadoFinanciero;
DROP TABLE IF EXISTS contable.Pago;
DROP TABLE IF EXISTS contable.Comprobante;
DROP TABLE IF EXISTS infraestructura.UnidadFuncional;
DROP TABLE IF EXISTS general.LogRegistroRechazado;
DROP TABLE IF EXISTS general.ReporteGrafico;
GO
DROP TABLE IF EXISTS contable.GastoOrdinario;
DROP TABLE IF EXISTS contable.GastoExtraordinario;
DROP TABLE IF EXISTS persona.Servicio;
DROP TABLE IF EXISTS persona.CuentaBancaria;
GO
DROP TABLE IF EXISTS persona.Persona;
DROP TABLE IF EXISTS infraestructura.Consorcio;
DROP TABLE IF EXISTS general.Log;
GO

----------------------------------------------------------------------------------------------------------------------------------
	/* TABLES */
----------------------------------------------------------------------------------------------------------------------------------


CREATE TABLE general.Log (
    LogID INT IDENTITY(1,1) PRIMARY KEY,
    Proceso VARCHAR(64) NOT NULL, -- disminuido de 255 a 64, no hay nombres de proceso tan largos
    Tipo VARCHAR(11) NOT NULL CHECK (Tipo IN ('INFO', 'ADVERTENCIA', 'ERROR')),
    Mensaje VARCHAR(1024) NOT NULL,
    ReporteXML XML,
    NumeroDeError INT,
    MensajeDeError NVARCHAR(1024), -- para el retorno de ERROR_MESSAGE() que es nvarchar
    LineaDeError INT,
    FechaHora AS SYSDATETIME(), -- guardamos la fecha y hora del sistema
    Usuario AS SUSER_SNAME(), -- guardamos el nombre del usuario que genero el reporte
);
GO


CREATE TABLE general.LogRegistroRechazado (
    LogRegistroRechazadoID INT IDENTITY(1,1) PRIMARY KEY,
	LogID INT NOT NULL,
    Motivo CHAR(19) NOT NULL CHECK (Motivo IN ('CORRUPTO', 'DUPLICADO EN ARCHIVO', 'DUPLICADO EN TABLA')),
    RegistroXML XML,

	CONSTRAINT FK_LogRegistroRechazado_Log FOREIGN KEY(LogID) REFERENCES general.Log(LogID)
);
GO


CREATE TABLE infraestructura.Consorcio(
	ConsorcioID INT IDENTITY(1,1) PRIMARY KEY,
	NombreDelConsorcio VARCHAR(64) NOT NULL, -- luego de analizarlo, el promedio de longitud de nombre de una empresa es de entre 20 y 50 caracteres
	Domicilio VARCHAR(128) NOT NULL,
	CantidadUF INT NOT NULL,
	Superficie DECIMAL(6,2) NOT NULL,

	CONSTRAINT CK_Consorcio_CantidadUFValida
        CHECK (CantidadUF > 0),

	CONSTRAINT CK_Consorcio_SuperficieValida
        CHECK (Superficie > 0)
);
GO


CREATE TABLE general.ReporteGrafico (
    ReporteGraficoID INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    ConsorcioID INT NOT NULL,
    PeriodoAnio INT NOT NULL,
    PeriodoMes INT NOT NULL,
    URLApi VARCHAR(MAX) NOT NULL, 
    FechaHora AS SYSDATETIME(), -- guardamos la fecha y hora del sistema
    Usuario AS SUSER_SNAME(), -- guardamos el nombre del usuario que genero el reporte
        
    CONSTRAINT FK_ReporteGrafico_Consorcio FOREIGN KEY (ConsorcioID)
        REFERENCES infraestructura.Consorcio(ConsorcioID)
);
GO


CREATE TABLE persona.Persona(
	PersonaID INT IDENTITY(1,1) PRIMARY KEY,
	DNI INT,                -- se cifrara posteriormenete en el script 12_CifradoDB.sql
	Nombre VARCHAR(128),    -- se cifrara posteriormenete en el script 12_CifradoDB.sql
	Apellido VARCHAR(128),  -- se cifrara posteriormenete en el script 12_CifradoDB.sql
	Mail VARCHAR(255),      -- se cifrara posteriormenete en el script 12_CifradoDB.sql
	Telefono VARCHAR(20),   -- se cifrara posteriormenete en el script 12_CifradoDB.sql
	EsPropietario BIT NOT NULL,

	CONSTRAINT UQ_Persona_Unica -- el DNI solo no es confiable, problemas historicos en Argentina
		UNIQUE (DNI, Nombre, Apellido), -- no permitimos el ingreso si los 3 son iguales

	CONSTRAINT CK_Persona_MailValido -- normalizado con funcion, CHECK para integridad
        CHECK (Mail IS NULL OR Mail LIKE '_%@__%.__%'),

	CONSTRAINT CK_Persona_TelefonoValido -- normalizado con funcion, CHECK para integridad, permite NULL
        CHECK (Telefono IS NULL OR (LEN(Telefono) >= 7 AND Telefono NOT LIKE '%[^0-9]%')),

	CONSTRAINT CK_Persona_DNIValido -- normalizado con funcion, CHECK para integridad
		CHECK (DNI >= 0 AND DNI < 100000000),
);
GO


CREATE TABLE persona.CuentaBancaria(
	NroClaveUniformeID CHAR(22), -- se cifrara posteriormenete en el script 12_CifradoDB.sql
	PersonaID INT NOT NULL,

    CONSTRAINT PK_CuentaBancaria PRIMARY KEY (NroClaveUniformeID),

	CONSTRAINT FK_CuentaBancaria_Persona
		FOREIGN KEY (PersonaID) REFERENCES persona.Persona(PersonaID),

	CONSTRAINT CK_CuentaBancaria_NroClaveUniformeValido
        CHECK (LEN(NroClaveUniformeID) = 22 AND NroClaveUniformeID NOT LIKE '%[^0-9]%')
);
GO


CREATE TABLE infraestructura.UnidadFuncional(
	NroUnidadFuncionalID INT,
	ConsorcioID INT  NOT NULL,
	NroClaveUniformeID CHAR(22), -- se cifrara posteriormenete en el script 12_CifradoDB.sql
	PropietarioID INT NOT NULL,
	InquilinoID INT,
	Piso CHAR(2) NOT NULL,
	Departamento CHAR(1) NOT NULL,
	Superficie DECIMAL(6,2) NOT NULL CHECK (Superficie > 0),
	SuperficieBaulera DECIMAL(6,2) NOT NULL CHECK (SuperficieBaulera >= 0),
	SuperficieCochera DECIMAL(6,2) NOT NULL CHECK (SuperficieCochera >= 0),
	Coeficiente DECIMAL(3,1) NOT NULL CHECK(Coeficiente > 0),

	CONSTRAINT PK_UnidadFuncional
		PRIMARY KEY (ConsorcioID, NroUnidadFuncionalID),

	CONSTRAINT FK_UnidadFuncional_Consorcio
		FOREIGN KEY (ConsorcioID) REFERENCES infraestructura.Consorcio(ConsorcioID),

	CONSTRAINT FK_UnidadFuncional_CuentaBancaria
		FOREIGN KEY (NroClaveUniformeID) REFERENCES persona.CuentaBancaria(NroClaveUniformeID),

	CONSTRAINT FK_UnidadFuncionalPro_Persona
		FOREIGN KEY (PropietarioID) REFERENCES persona.Persona(PersonaID),

	CONSTRAINT FK_UnidadFuncionalInq_Persona
		FOREIGN KEY (InquilinoID) REFERENCES persona.Persona(PersonaID),

	CONSTRAINT UQ_UnidadFuncional_DepartamentoPorPisoUnico
		UNIQUE (ConsorcioID, Piso, Departamento),
);
GO


CREATE TABLE persona.Servicio(
	ServicioID INT identity(1,1) PRIMARY KEY,
	Detalle VARCHAR(255) NOT NULL,
	RazonSocial VARCHAR(255) NOT NULL,
	Categoria CHAR(24) NOT NULL,
	ConsorcioID INT NOT NULL,

	CONSTRAINT FK_Servicio_Consorcio
        FOREIGN KEY (ConsorcioID) REFERENCES infraestructura.Consorcio(ConsorcioID),

	CONSTRAINT UQ_Servicio_ServicioUnico
		UNIQUE (ConsorcioID, RazonSocial, Detalle),

	CONSTRAINT CK_Servicio_CategoriaValida CHECK (
    Categoria IN (
        'GASTOS BANCARIOS', 
        'GASTOS DE ADMINISTRACION', 
        'SEGUROS', 
		'GASTOS GENERALES',
        'SERVICIOS PUBLICOS', 
        'GASTOS DE LIMPIEZA'
        -- categorias del archivo
    ))
);
GO


CREATE TABLE contable.GastoOrdinario(
	GastoOrdinarioID INT IDENTITY(1,1) PRIMARY KEY,
	Periodo DATE NOT NULL,
	Categoria CHAR(24) NOT NULL,
	ConsorcioID INT NOT NULL,
	Importe DECIMAL(12,2) NOT NULL CHECK (Importe >= 0),

	CONSTRAINT FK_GastoOrdinario_Consorcio FOREIGN KEY (ConsorcioID) REFERENCES infraestructura.Consorcio(ConsorcioID),

	CONSTRAINT UQ_GastoOrdinario_GastoUnicoPorPeriodo UNIQUE (Periodo, Categoria, ConsorcioID),

	CONSTRAINT CK_GastoOrdinario_CategoriaValida CHECK (
    Categoria IN (
        'GASTOS BANCARIOS', 
        'GASTOS DE ADMINISTRACION', 
        'SEGUROS', 
		'GASTOS GENERALES',
        'SERVICIOS PUBLICOS', 
        'GASTOS DE LIMPIEZA'
        -- categorias del archivo
    ))
);
GO


CREATE TABLE contable.GastoExtraordinario(
	GastoExtraordinarioID INT IDENTITY(1,1) PRIMARY KEY,
	ConsorcioID INT NOT NULL,
	Periodo DATE NOT NULL,
	Tipo CHAR(12) NOT NULL CHECK (Tipo IN ('REPARACION', 'CONSTRUCCION')),
	ModalidadPago CHAR(6) NOT NULL CHECK (ModalidadPago IN ('TOTAL', 'CUOTAS')),
	CuotasTotales INT,
	CuotaActual INT,
	
	Importe DECIMAL(12,2) NOT NULL CHECK (Importe > 0),

	CONSTRAINT FK_GastoExtraordinario_Consorcio FOREIGN KEY (ConsorcioID) REFERENCES infraestructura.Consorcio(ConsorcioID),

	CONSTRAINT UQ_GastoExtraordinario_GastoUnicoPorPeriodo UNIQUE (Periodo, Tipo, ConsorcioID),

	CONSTRAINT CK_GastoExtraordinario_ReglasDeCuotas CHECK (
        -- si el pago es TOTAL las dps columnas de las cuotas tienem que ser NULL
        (ModalidadPago = 'TOTAL' AND CuotasTotales IS NULL AND CuotaActual IS NULL) OR
        -- si el pago es en CUOTAS,las dos columnas de las cuotas no pueden ser NULL.
        (ModalidadPago = 'CUOTAS' AND CuotasTotales IS NOT NULL AND CuotaActual IS NOT NULL)
    )
);
GO


CREATE TABLE contable.Comprobante (
    FacturaID INT IDENTITY(1,1) PRIMARY KEY,
    GastoOrdinarioID INT NOT NULL,
	ServicioID INT NOT NULL,
	TipoComprobante CHAR(9) NOT NULL CHECK (TipoComprobante IN ('FACTURA', 'SUELDO', 'HONORARIO')),
    NroFactura VARCHAR(50), -- puede repetirse entre diferentes proveedores, por eso hay otro campo PK IDENTITY
    FechaEmision DATE NOT NULL,
    Importe DECIMAL(12,2) NOT NULL CHECK (Importe > 0),
	Detalle VARCHAR(255), 

    CONSTRAINT FK_Comprobante_GastoOrdinario FOREIGN KEY (GastoOrdinarioID) REFERENCES contable.GastoOrdinario(GastoOrdinarioID),

	CONSTRAINT FK_Comprobante_Proveedor FOREIGN KEY (ServicioID) REFERENCES persona.Servicio(ServicioID),

	CONSTRAINT CK_Comprobante_ReglasPorTipo CHECK (
        (TipoComprobante <> 'FACTURA') OR (TipoComprobante = 'FACTURA' AND NroFactura IS NOT NULL)
    )
);
GO


CREATE TABLE contable.Pago(
	PagoID INT IDENTITY(10000,1) PRIMARY KEY, -- partimos de 10000 porque consideramos al maestro como "La Verdad"
	Fecha DATE NOT NULL,
	NroClaveUniformeID CHAR(22) NOT NULL, -- se cifrara posteriormenete en el script 12_CifradoDB.sql
	Concepto CHAR(20) NOT NULL CHECK (Concepto IN ('ORDINARIO','EXTRAORDINARIO')),
	Importe DECIMAL(12,2) NOT NULL CHECK (Importe > 0),

	CONSTRAINT FK_Pago_CuentaBancaria FOREIGN KEY (NroClaveUniformeID) REFERENCES persona.CuentaBancaria(NroClaveUniformeID),
);
GO


CREATE TABLE contable.Prorrateo(
	ProrrateoID INT IDENTITY(1,1) PRIMARY KEY,

	ConsorcioID INT NOT NULL,
	NroUnidadFuncionalID INT NOT NULL,
	PersonaID INT NOT NULL,

	Periodo DATE NOT NULL,
	FechaVencimiento1 DATE NOT NULL,
	FechaVencimiento2 DATE NOT NULL,

	PorcentajePorM2 DECIMAL(3,1) NOT NULL,

	ExpOrd DECIMAL(12,2) NOT NULL CHECK (ExpOrd >= 0),
	ExpExtraOrd DECIMAL(12,2) NOT NULL CHECK (ExpExtraOrd >= 0),
	SaldoAnterior DECIMAL(12,2) NOT NULL, --entre saldo y pagos, se obtiene deuda, consideramos valores negativos como saldo acreedor
	PagosRecibidos DECIMAL(12,2) NOT NULL CHECK (PagosRecibidos >= 0),
	InteresPorMora DECIMAL(12,2) NOT NULL CHECK (InteresPorMora >= 0),

	FormaEnvioPropietario VARCHAR(20) NOT NULL CHECK (FormaEnvioPropietario IN ('EMAIL', 'WHATSAPP', 'IMPRESO')),
	FormaEnvioInquilino VARCHAR(20) CHECK (FormaEnvioInquilino IS NULL OR FormaEnvioInquilino IN ('EMAIL', 'WHATSAPP', 'IMPRESO')),

    Deuda AS ( -- calculamos la deuda como el acumulado de lo anterior, mas intereses, mas expensas actuales
		SaldoAnterior + 
		InteresPorMora + 
		ExpOrd + 
		ExpExtraOrd
	),

	SaldoActual AS ( -- es positivo, significa que hay deuda, si es cero se ha pagado la totalidad, si es negativo se ha pagado de más
		(SaldoAnterior + InteresPorMora + ExpOrd + ExpExtraOrd) - PagosRecibidos
	),

	CONSTRAINT FK_Prorrateo_UnidadFuncional FOREIGN KEY  (ConsorcioID, NroUnidadFuncionalID) 
		REFERENCES infraestructura.UnidadFuncional(ConsorcioID, NroUnidadFuncionalID) ,

	CONSTRAINT FK_Prorrateo_Persona FOREIGN KEY (PersonaID) REFERENCES persona.Persona(PersonaID),

	CONSTRAINT UQ_Prorrateo_ProrrateoUnicoPorPeriodoPorUF UNIQUE (Periodo, NroUnidadFuncionalID, ConsorcioID)
);
GO


CREATE TABLE contable.EstadoFinanciero(
	EstadoFinancieroID INT IDENTITY(1,1) PRIMARY KEY,
	ConsorcioID INT NOT NULL,
	Periodo DATE NOT NULL,

	SaldoAnterior DECIMAL(12,2) NOT NULL, -- consideramos saldo negativo por deudas

	PagosEnTermino DECIMAL(12,2) NOT NULL CHECK (PagosEnTermino >= 0),
	PagosAdeudados DECIMAL(12,2) NOT NULL CHECK (PagosAdeudados >= 0),
	PagosAdelantados DECIMAL(12,2) NOT NULL CHECK (PagosAdelantados >= 0),

	EgresosPorGastos DECIMAL(12,2) NOT NULL CHECK (EgresosPorGastos >= 0),

	SaldoCierre AS (
		(SaldoAnterior + PagosEnTermino + PagosAdeudados) - EgresosPorGastos
	),

	CONSTRAINT FK_EstadoFinanciero_Consorcio FOREIGN KEY (ConsorcioID) REFERENCES infraestructura.Consorcio(ConsorcioID),

	CONSTRAINT UQ_EstadoFinanciero_UnicoPorPeriodo UNIQUE (ConsorcioID, Periodo)
);
GO


----------------------------------------------------------------------------------------------------------------------------------
	/* FUNCTIONS */
----------------------------------------------------------------------------------------------------------------------------------


CREATE OR ALTER FUNCTION general.f_RemoverBlancos (
    @Texto VARCHAR(MAX)
)
RETURNS VARCHAR(MAX)
AS
BEGIN
    DECLARE @TextoNorm VARCHAR(MAX);

    IF @Texto IS NULL
        RETURN NULL;

    SET @TextoNorm = @Texto;
    
    SET @TextoNorm = REPLACE(@TextoNorm, CHAR(9), ''); -- tabulacion   
    SET @TextoNorm = REPLACE(@TextoNorm, CHAR(10), ''); -- salto de linea    
    SET @TextoNorm = REPLACE(@TextoNorm, CHAR(13), ''); -- retorno de carro    
	SET @TextoNorm = REPLACE(@TextoNorm, CHAR(32), ''); -- espacio
    SET @TextoNorm = REPLACE(@TextoNorm, CHAR(160), ''); -- espacio no separable

    RETURN @TextoNorm;
END
GO


CREATE OR ALTER FUNCTION general.f_NormalizarTelefono (
    @Telefono VARCHAR(30)
)
RETURNS VARCHAR(20)
AS
BEGIN
    DECLARE @TelefonoNorm VARCHAR(30);

    IF @Telefono IS NULL -- si es NULL retonramos
        RETURN NULL;

    SET @TelefonoNorm = @Telefono;
	SET @TelefonoNorm = general.f_RemoverBlancos(@TelefonoNorm); -- quitamos espacios si los hay
    SET @TelefonoNorm = REPLACE(@TelefonoNorm, '-', ''); -- quitamos guines si los hay
    SET @TelefonoNorm = REPLACE(@TelefonoNorm, '+', ''); -- quitamos signo mas si los hay (telefono internacional)

    IF @TelefonoNorm LIKE '%[^0-9]%' -- si quedan otro caracteres aparte de numeros, retornamos NULL
        RETURN NULL; 

    IF LEN(@TelefonoNorm) NOT BETWEEN 7 AND 13 -- si el largo del telefono no coincide retornamos NULL
        RETURN NULL; 

    RETURN @TelefonoNorm;
END
GO


CREATE OR ALTER FUNCTION general.f_NormalizarDNI (
    @DNITexto VARCHAR(12) 
)
RETURNS INT -- cubre 2 puntos y dos digitos mas a los DNI actuales
AS
BEGIN
    DECLARE @DNINorm VARCHAR(20);

    IF @DNITexto IS NULL -- si es NULL retonramos
        RETURN NULL;

    SET @DNINorm = @DNITexto;
	SET @DNINorm= general.f_RemoverBlancos(@DNINorm); -- quitamos espacios si los hay
    SET @DNINorm = REPLACE(@DNINorm, '.', ''); -- quitamos puntos si los hay
    
	IF NULLIF(@DNINorm, '') IS NULL -- si no quedan caracteres
		RETURN NULL;

    IF @DNINorm LIKE '%[^0-9]%' -- si quedan otro caracteres aparte de numeros, retornamos NULL
        RETURN NULL; 

	IF LEN(@DNINorm) > 10 -- seria muy largo
		RETURN NULL;

    RETURN TRY_CAST(@DNINorm AS INT);
END
GO


CREATE OR ALTER FUNCTION general.f_NormalizarMail (
    @Mail VARCHAR(255)
)
RETURNS VARCHAR(255)
AS
BEGIN
    DECLARE @MailNorm VARCHAR(255);

    IF @Mail IS NULL
        RETURN NULL;

    SET @MailNorm = general.f_RemoverBlancos(@Mail);

    IF NULLIF(@MailNorm, '') IS NULL
        RETURN NULL; 

    IF (
        @MailNorm NOT LIKE '_%@__%.__%' OR 
        @MailNorm LIKE '%@%@%' OR   -- hay varios @
        @MailNorm LIKE '@%' OR      -- no hay algo antes del @
		@MailNorm LIKE '%@' OR      -- no hay despues del @
		@MailNorm LIKE '.%'	OR		-- comienza por '.'   
		@MailNorm LIKE '%.' 		-- no tiene dominio ya que termina en '.'
    )
		RETURN NULL;

    RETURN LOWER(@MailNorm); -- consideramos los correos como case insensitive
END
GO


CREATE OR ALTER FUNCTION general.f_NormalizarImporte (
    @ImporteTexto VARCHAR(50)
)
RETURNS DECIMAL(12, 2)
AS
BEGIN

    IF @ImporteTexto IS NULL
        RETURN NULL;

    DECLARE @ImporteTextoNorm VARCHAR(50);
    SET @ImporteTextoNorm = @ImporteTexto;

    SET @ImporteTextoNorm = REPLACE(@ImporteTextoNorm, '$', '');
    SET @ImporteTextoNorm = LTRIM(RTRIM(@ImporteTextoNorm));
    SET @ImporteTextoNorm = REPLACE(@ImporteTextoNorm, '.', '');
    SET @ImporteTextoNorm = REPLACE(@ImporteTextoNorm, ',', '.');

    RETURN TRY_CAST(@ImporteTextoNorm AS DECIMAL(12, 2));
END
GO


CREATE OR ALTER FUNCTION general.f_NormalizarFecha_DDMMYYYY (
    @FechaTexto VARCHAR(20)
)
RETURNS DATE
AS
BEGIN
    IF @FechaTexto IS NULL
        RETURN NULL;

    DECLARE @TextoLimpio VARCHAR(20);

    SET @TextoLimpio = REPLACE(@FechaTexto, ' ', '');

    RETURN TRY_CONVERT(DATE, @TextoLimpio, 103); -- el estilo dd/mm/yyyy es el 103
END
GO


----------------------------------------------------------------------------------------------------------------------------------
	/* STORED PROCEDURE */
----------------------------------------------------------------------------------------------------------------------------------


----------------------------------------------------------------------------------------------------------------------------------
	/* STORED PROCEDURE general.p_RegistrarLog */
----------------------------------------------------------------------------------------------------------------------------------

CREATE OR ALTER PROCEDURE general.p_RegistrarLog
    @Proceso VARCHAR(64),
    @Tipo VARCHAR(11),
    @Mensaje VARCHAR(1024),
    @ReporteXML XML = NULL,
	@LogIDOut INT = NULL OUTPUT -- opcional
AS
BEGIN
    SET NOCOUNT ON;

    IF @Tipo = 'ERROR' AND ERROR_NUMBER() IS NOT NULL --
    BEGIN
        INSERT INTO general.Log (Proceso, Tipo, Mensaje, ReporteXML, NumeroDeError, MensajeDeError, LineaDeError)
        VALUES (
            @Proceso, 
            @Tipo, 
            @Mensaje, 
            @ReporteXML, 
            ERROR_NUMBER(), -- retorna el ultimo error de SQL
            ERROR_MESSAGE(), -- retorna el texto asociado al numero de error anterior
            ERROR_LINE() -- retorna el numero de linea donde ocurrio el error
        );
    END
    ELSE
    BEGIN
        INSERT INTO general.Log (Proceso, Tipo, Mensaje, ReporteXML)
        VALUES (@Proceso, @Tipo, @Mensaje, @ReporteXML);
    END

	SET @LogIDOut = SCOPE_IDENTITY(); -- retorna el valor identity de la ultima insercion
END;
GO


----------------------------------------------------------------------------------------------------------------------------------
	/* STORED PROCEDURE contable.p_CalcularProrrateoMensual */
----------------------------------------------------------------------------------------------------------------------------------


CREATE OR ALTER PROCEDURE contable.p_CalcularProrrateoMensual
    @Periodo DATE -- debe ser el primer dia del mes
AS
BEGIN
    SET NOCOUNT ON;

    PRINT CHAR(10) + '============== INCIO DE p_CalcularProrrateoMensual ==============';

    DROP TABLE IF EXISTS #DatosCalculados;

    DECLARE @PeriodoFin DATE = EOMONTH(@Periodo);
    DECLARE @PrimerDiaMesSiguiente DATE = DATEADD(month, 1, @Periodo); -- consideramos que se envia la expensa del mes anterior a pagar este mes

    CREATE TABLE #DatosCalculados (
        ConsorcioID INT NOT NULL,
        NroUnidadFuncionalID INT,
        PersonaID INT NOT NULL,
        NroClaveUniformeID CHAR(22) NOT NULL,
        SuperficieTotal DECIMAL(10,2) NOT NULL,
        PorcentajeM2 DECIMAL(3,1) NOT NULL,
        ExpOrd DECIMAL(12,2) NOT NULL,
        ExpExtraOrd DECIMAL(12,2) NOT NULL,
        PagosRecibidos DECIMAL(12,2) NOT NULL,
        FormaEnvioPropietario VARCHAR(20) NOT NULL,
        FormaEnvioInquilino VARCHAR(20),
        PRIMARY KEY (ConsorcioID, NroUnidadFuncionalID)
    );

    SELECT
        Consorcio.ConsorcioID,
        ISNULL(Consorcio.Superficie, 0) AS SuperficieTotalConsorcio,
        ISNULL(LeftJoinConsorcio.GastoOrdTotal, 0) AS GastoOrdTotal,
        ISNULL(LeftJoinGastoExtraord.GastoExtraordTotal, 0) AS GastoExtraordTotal
    INTO #TotalesConsorcio
    FROM infraestructura.Consorcio AS Consorcio
    LEFT JOIN ( -- con los dos left join obtenemos los gastos ord y extraord para el consorcio en este periodo
        SELECT ConsorcioID, SUM(Importe) AS GastoOrdTotal -- hacemos la suma de todos los gastos ord individuales
        FROM contable.GastoOrdinario
        WHERE Periodo = @Periodo
        GROUP BY ConsorcioID
    ) AS LeftJoinConsorcio ON Consorcio.ConsorcioID = LeftJoinConsorcio.ConsorcioID
    LEFT JOIN (
        SELECT ConsorcioID, SUM(Importe) AS GastoExtraordTotal -- hacemos la suma de todos los gastos extraord individuales
        FROM contable.GastoExtraordinario
        WHERE Periodo = @Periodo
        GROUP BY ConsorcioID
    ) AS LeftJoinGastoExtraord ON Consorcio.ConsorcioID = LeftJoinGastoExtraord.ConsorcioID;

    INSERT INTO #DatosCalculados (
        ConsorcioID,
        NroUnidadFuncionalID, 
        PersonaID, 
        NroClaveUniformeID, 
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
        UnidadFuncional.NroClaveUniformeID,
        (ISNULL(UnidadFuncional.Superficie, 0) + ISNULL(UnidadFuncional.SuperficieCochera, 0) + ISNULL(UnidadFuncional.SuperficieBaulera, 0)),        
        ((ISNULL(UnidadFuncional.Superficie, 0) + ISNULL(UnidadFuncional.SuperficieCochera, 0) + ISNULL(UnidadFuncional.SuperficieBaulera, 0)) * 100 ) / Totales.SuperficieTotalConsorcio,
        (Totales.GastoOrdTotal * (ISNULL(UnidadFuncional.Superficie, 0) + ISNULL(UnidadFuncional.SuperficieCochera, 0) + ISNULL(UnidadFuncional.SuperficieBaulera, 0)) ) / Totales.SuperficieTotalConsorcio,
        (Totales.GastoExtraordTotal * (ISNULL(UnidadFuncional.Superficie, 0) + ISNULL(UnidadFuncional.SuperficieCochera, 0) + ISNULL(UnidadFuncional.SuperficieBaulera, 0)) ) / Totales.SuperficieTotalConsorcio,

        ISNULL((
            SELECT SUM(Pago.Importe) -- sumamos todos los pagos recibidos que corresponden a esta UnidadFuncional
            FROM contable.Pago Pago
            WHERE Pago.NroClaveUniformeID = UnidadFuncional.NroClaveUniformeID
            AND Pago.Fecha BETWEEN @Periodo AND @PeriodoFin
        ), 0),

        CASE -- orden de prioridad
            WHEN Propietario.Mail IS NOT NULL THEN 'EMAIL'
            WHEN Propietario.Telefono IS NOT NULL THEN 'WHATSAPP'
            ELSE 'IMPRESO'
        END, 
        CASE -- tambien vemos si existe un inquilino en la UnidadFuncional
            WHEN UnidadFuncional.InquilinoID IS NULL THEN NULL
            WHEN Inquilino.Mail IS NOT NULL THEN 'EMAIL'
            WHEN Inquilino.Telefono IS NOT NULL THEN 'WHATSAPP'
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
                ) AS Numero -- este numero representa el numero de regsitro para cada UF
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
                    CASE -- dependiendo de la fecha, asignamos un interes 0, 2% o 5%
                        WHEN GETDATE() > ProrrateoAnterior.FechaVencimiento1 THEN ISNULL(ProrrateoAnterior.SaldoActual, 0.00) * 0.02
                        WHEN GETDATE() > ProrrateoAnterior.FechaVencimiento2 THEN ISNULL(ProrrateoAnterior.SaldoActual, 0.00) * 0.05
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



----------------------------------------------------------------------------------------------------------------------------------
	/* STORED PROCEDURE contable.p_CalcularEstadoFinanciero */
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
            ON Pago.NroClaveUniformeID = CuentaBancaria.NroClaveUniformeID
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
	/* INSERT DE REGISTROS DE CONTROL */
----------------------------------------------------------------------------------------------------------------------------------


INSERT INTO persona.Persona (
	DNI,
	Nombre,
	Apellido,
	Mail,
	Telefono,
	EsPropietario
	)
VALUES (
	0,
	'PROPIETARIO',
	'INDETERMINADO',
	NULL,
	NULL,
	1
);
GO
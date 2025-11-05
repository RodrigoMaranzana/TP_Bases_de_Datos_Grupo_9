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
	/* TABLES */
----------------------------------------------------------------------------------------------------------------------------------


CREATE TABLE general.Log (
    LogID INT IDENTITY(1,1) PRIMARY KEY,
    Proceso VARCHAR(255) NOT NULL,
    Tipo VARCHAR(11) NOT NULL CHECK (Tipo IN ('INFO', 'ADVERTENCIA', 'ERROR')),
    Mensaje VARCHAR(1024) NOT NULL,
    ReporteXML XML,
    NumeroDeError INT,
    MensajeDeError NVARCHAR(1024), -- para el retorno de ERROR_MESSAGE() que es nvarchar
    LineaDeError INT,
	FechaHora AS SYSDATETIME(),
    Usuario AS SUSER_SNAME()
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
	NombreDelConsorcio VARCHAR(255) NOT NULL,
	Domicilio VARCHAR(255) NOT NULL,
	CantidadUF INT NOT NULL,
	Superficie DECIMAL(6,2) NOT NULL,

	CONSTRAINT CK_Consorcio_CantidadUFValida
        CHECK (CantidadUF > 0),

	CONSTRAINT CK_Consorcio_SuperficieValida
        CHECK (Superficie > 0)
);
GO


CREATE TABLE persona.Persona(
	PersonaID INT IDENTITY(1,1) PRIMARY KEY,
	DNI INT, -- el DNI solo no es confiable, problemas historicos en Argentina
	Nombre VARCHAR(255),
	Apellido VARCHAR(255),
	Mail VARCHAR(255),
	Telefono VARCHAR(20),

	CONSTRAINT UQ_Persona_Unica
		UNIQUE (DNI, Nombre, Apellido), -- no permitimos el ingreso si los 3 son iguales

	CONSTRAINT CK_Persona_MailValido -- normalizado con funcion, CHECK para integridad
        CHECK (Mail IS NULL OR Mail LIKE '_%@__%.__%'),

	CONSTRAINT CK_Persona_TelefonoValido -- normalizado con funcion, CHECK para integridad, permite NULL
        CHECK (Telefono IS NULL OR (LEN(Telefono) >= 7 AND Telefono NOT LIKE '%[^0-9]%')),

	CONSTRAINT CK_Persona_DNIValido -- normalizado con funcion, CHECK para integridad
		CHECK (DNI >= 0 AND DNI < 100000000),
);
GO


CREATE TABLE persona.Propietario(
	PropietarioID INT IDENTITY(1,1) PRIMARY KEY,
	PersonaID INT NOT NULL UNIQUE, 

	CONSTRAINT FK_Propietario_Persona
		FOREIGN KEY (PersonaID) REFERENCES persona.Persona(PersonaID)
);
GO


CREATE TABLE persona.Inquilino(
	InquilinoID INT IDENTITY(1,1) PRIMARY KEY,
	PersonaID INT NOT NULL UNIQUE,

	CONSTRAINT FK_Inquilino_Persona
		FOREIGN KEY (PersonaID) REFERENCES persona.Persona(PersonaID)
);
GO


CREATE TABLE persona.CuentaBancaria(
	NroClaveUniformeID CHAR(22) PRIMARY KEY,
	PersonaID INT NOT NULL,

	CONSTRAINT FK_CuentaBancaria_Persona
		FOREIGN KEY (PersonaID) REFERENCES persona.Persona(PersonaID),

	CONSTRAINT CK_CuentaBancaria_NroClaveUniformeValido
        CHECK (LEN(NroClaveUniformeID) = 22 AND NroClaveUniformeID NOT LIKE '%[^0-9]%')
);
GO


CREATE TABLE infraestructura.UnidadFuncional(
	NroUnidadFuncionalID INT,
	ConsorcioID INT  NOT NULL,
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

	CONSTRAINT FK_UnidadFuncional_Propietario
		FOREIGN KEY (PropietarioID) REFERENCES persona.Propietario(PropietarioID),

	CONSTRAINT FK_UnidadFuncional_Inquilino
		FOREIGN KEY (InquilinoID) REFERENCES persona.Inquilino(InquilinoID),

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
        'SERVICIOS PUBLICOS', 
        'GASTOS DE LIMPIEZA'
        -- categorias del archivo
    ))
);
GO


CREATE TABLE contable.GastoOrdinario(
	GastoOrdinarioID INT IDENTITY(1,1) PRIMARY KEY,
	Periodo DATE NOT NULL,
	Categoria VARCHAR(32) NOT NULL,
	ConsorcioID INT NOT NULL,
	Importe DECIMAL(12,2) NOT NULL CHECK (Importe >= 0),

	CONSTRAINT FK_GastoOrdinario_Consorcio FOREIGN KEY (ConsorcioID) REFERENCES infraestructura.Consorcio(ConsorcioID),

	CONSTRAINT UQ_GastoOrdinario_GastoUnicoPorPeriodo UNIQUE (Periodo, Categoria, ConsorcioID)
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
	PagoID INT IDENTITY(10000,1) PRIMARY KEY,
	Fecha DATE NOT NULL,
	ConsorcioID INT,
	NroClaveUniformeID CHAR(22) NOT NULL,
	NroUnidadFuncionalID INT,
	Importe DECIMAL(12,2) NOT NULL CHECK (Importe > 0),

	CONSTRAINT FK_Pago_CuentaBancaria FOREIGN KEY (NroClaveUniformeID) REFERENCES persona.CuentaBancaria(NroClaveUniformeID),

	CONSTRAINT FK_Pago_UnidadFuncional FOREIGN KEY (ConsorcioID, NroUnidadFuncionalID) 
		REFERENCES infraestructura.UnidadFuncional(ConsorcioID, NroUnidadFuncionalID)
);
GO


CREATE TABLE contable.Prorrateo(
	ProrrateoID INT IDENTITY(1,1) PRIMARY KEY,

	ConsorcioID INT NOT NULL,
	NroUnidadFuncionalID INT NOT NULL,
	PropietarioID INT NOT NULL,

	Periodo DATE NOT NULL,
	FechaVencimiento1 DATE NOT NULL,
	FechaVencimiento2 DATE NOT NULL,

	PorcentajePorM2 DECIMAL(3,1) NOT NULL,

	CostoBaulera  DECIMAL(12,2) NOT NULL CHECK (CostoBaulera >= 0),
	CostoCochera DECIMAL(12,2) NOT NULL CHECK (CostoCochera >= 0),
	ExpOrd DECIMAL(12,2) NOT NULL CHECK (ExpOrd >= 0),
	ExpExtraOrd DECIMAL(12,2) NOT NULL CHECK (ExpExtraOrd >= 0),
	SaldoAnterior DECIMAL(12,2) NOT NULL, --entre saldo y pagos, se obtiene deuda, consideramos valores negativos
	PagosRecibidos DECIMAL(12,2) NOT NULL CHECK (PagosRecibidos >= 0),
	InteresPorMora DECIMAL(12,2) NOT NULL CHECK (InteresPorMora >= 0),

	FormaEnvioPropietario VARCHAR(20) NOT NULL CHECK (FormaEnvioPropietario IN ('EMAIL', 'WHATSAPP', 'IMPRESO')),
	FormaEnvioInquilino VARCHAR(20) CHECK (FormaEnvioInquilino IS NULL OR FormaEnvioInquilino IN ('EMAIL', 'WHATSAPP', 'IMPRESO')),

	Deuda AS (SaldoAnterior - PagosRecibidos),
	Total AS (
		(SaldoAnterior - PagosRecibidos) + 
		InteresPorMora + 
		ExpOrd + 
		ExpExtraOrd + 
		CostoCochera + 
		CostoBaulera
	),

	CONSTRAINT FK_Prorrateo_UnidadFuncional FOREIGN KEY  (ConsorcioID, NroUnidadFuncionalID) 
		REFERENCES infraestructura.UnidadFuncional(ConsorcioID, NroUnidadFuncionalID) ,

	CONSTRAINT FK_Prorrateo_Propietario FOREIGN KEY (PropietarioID) REFERENCES persona.Propietario(PropietarioID),

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
		(SaldoAnterior + PagosEnTermino + PagosAdeudados + PagosAdelantados) - EgresosPorGastos
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


CREATE OR ALTER PROCEDURE general.p_RegistrarLog
    @Proceso VARCHAR(255),
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
            ERROR_NUMBER(), 
            ERROR_MESSAGE(), 
            ERROR_LINE()
        );
    END
    ELSE
    BEGIN
        INSERT INTO general.Log (Proceso, Tipo, Mensaje, ReporteXML)
        VALUES (@Proceso, @Tipo, @Mensaje, @ReporteXML);
    END

	SET @LogIDOut = SCOPE_IDENTITY();
END;
GO


----------------------------------------------------------------------------------------------------------------------------------
	/* INSERT DE REGISTROS DE CONTROL */
----------------------------------------------------------------------------------------------------------------------------------

/** Los archivos maestros solo incluyen o un propietario o un inquilino para cada Unidad Funcional
	Si solo vinculamos a uno de ellos a la UF, cuando una UF este alquilada el sistema no podria
	dividir el cobro de las expensas extraordinarias, por solo conocer la Clave Uniforme del inquilino.
	Debido a la situación que plantea todo este escenario, el consorcio no deberia poder permitirse
	la espera de la carga de los propietarios para comenzar a cobrar las expensas ordinarias que además
	representan la mayor parte de los gastos del consorcio, ya que las extraordinarios tienen montos
	considerablemente menores. Por esta razón consideramos que la mejor estrategia es tener los datos
	de forma opeativa lo antes posible para que el consorcio pueda comenzar a administrar correctamente
	los pagos. La deuda de las expensas extraordinarias de las UF alquiladas puede acumularse durante
	la espera de la actualización de los propietarios faltantes.
**/

INSERT INTO persona.Persona (
	DNI,
	Nombre,
	Apellido,
	Mail,
	Telefono
	)
VALUES (
	0,
	'PROPIETARIO',
	'INDETERMINADO',
	NULL,
	NULL
);
GO

INSERT INTO persona.Propietario(PersonaID)
VALUES (1);
GO
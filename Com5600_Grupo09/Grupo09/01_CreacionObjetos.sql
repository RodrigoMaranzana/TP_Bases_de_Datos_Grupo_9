/**********************************************************
 * Bases de Datos Aplicada - Comisión 5600
 * GRUPO 09
 *
 * Archivo: 01_CreacionTablas.sql
 * Enunciado cumplimentado: Creación de las tablas del proyecto.
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



CREATE TABLE general.LogImportaciones (
    LogImportacionesID INT IDENTITY(1,1) PRIMARY KEY,
    FechaHora  DATETIME DEFAULT GETDATE(),
    NombreImportacion VARCHAR(128),
    FilasInsertadas INT,
    FilasDuplicadas INT,
    FilasCorruptas INT,
	Detalle VARCHAR(128)
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

CREATE TABLE persona.Habitante(
	DNI INT,
	Nombre VARCHAR(255),
	Apellido VARCHAR(255),
	Mail VARCHAR(255),
	Telefono VARCHAR(20),
	EsInquilino BIT,

	CONSTRAINT PK_Habitante
		PRIMARY KEY (DNI, Nombre, Apellido), -- el DNI solo no es confiable, problemas historicos en Argentina

	CONSTRAINT CK_Persona_MailValido -- normalizado con funcion, CHECK para integridad
        CHECK (Mail IS NULL OR Mail LIKE '_%@__%.__%'),

	CONSTRAINT CK_Persona_TelefonoValido -- normalizado con funcion, CHECK para integridad, permite NULL
        CHECK (Telefono IS NULL OR (LEN(Telefono) >= 7 AND Telefono NOT LIKE '%[^0-9]%')),

	CONSTRAINT CK_Persona_DNIValido -- normalizado con funcion, CHECK para integridad
		CHECK (DNI > 0 AND DNI < 100000000),
);
GO

CREATE TABLE persona.CuentaBancaria(
	NroClaveUniformeID CHAR(22) PRIMARY KEY,
	DNI INT NOT NULL, 
	Nombre VARCHAR(255)  NOT NULL,
	Apellido VARCHAR(255) NOT NULL,

	CONSTRAINT FK_CuentaBancaria_Habitante
		FOREIGN KEY (DNI, Nombre, Apellido)
		REFERENCES persona.Habitante(DNI, Nombre, Apellido),

	CONSTRAINT CK_CuentaBancaria_NroClaveUniformeValido
        CHECK (LEN(NroClaveUniformeID) = 22 AND NroClaveUniformeID NOT LIKE '%[^0-9]%')
);
GO

CREATE TABLE infraestructura.UnidadFuncional(
	NroUnidadFuncionalID INT IDENTITY(1,1),
	ConsorcioID INT  NOT NULL,
	NroClaveUniformeID CHAR(22),

	Piso CHAR(2) NOT NULL,
	Departamento CHAR(1) NOT NULL,
	Superficie DECIMAL(6,2) NOT NULL,
	TieneBaulera BIT NOT NULL,
	SuperficieBaulera DECIMAL(6,2), -- Deberia controlar que sea mayor o igual a cero o NULL (que no sea negativo)
	TieneCochera BIT NOT NULL,
	SuperficieCochera DECIMAL(6,2), -- Deberia controlar que sea mayor o igual a cero o NULL (que no sea negativo)
	Coeficiente DECIMAL(2,1) NOT NULL CHECK(Coeficiente > 0),

	CONSTRAINT PK_UnidadFuncional
		PRIMARY KEY (ConsorcioID, NroUnidadFuncionalID),

	CONSTRAINT FK_UnidadFuncional_Consorcio
		FOREIGN KEY (ConsorcioID)
		REFERENCES infraestructura.Consorcio(ConsorcioID),

	CONSTRAINT FK_UnidadFuncional_CuentaBancaria
		FOREIGN KEY (NroClaveUniformeID)
		REFERENCES persona.CuentaBancaria(NroClaveUniformeID),

	CONSTRAINT UQ_UnidadFuncional_DepartamentoPorPisoUnico
		UNIQUE (ConsorcioID, Piso, Departamento),

    CONSTRAINT CK_UnidadFuncional_SuperficieValida
        CHECK (Superficie > 0)
);
GO

CREATE TABLE persona.Servicio(
	ServicioID INT identity(1,1) PRIMARY KEY,
	Detalle VARCHAR(255) NOT NULL,
	RazonSocial VARCHAR(255) NOT NULL,
	Categoria CHAR(24) NOT NULL,
	ConsorcioID INT NOT NULL,

	CONSTRAINT FK_Servicio_Consorcio
        FOREIGN KEY (ConsorcioID)
        REFERENCES infraestructura.Consorcio(ConsorcioID),

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

CREATE TABLE contable.GastoMensual(
	GastoMensualID INT IDENTITY(1,1) PRIMARY KEY,
	Periodo DATE NOT NULL,
	Categoria VARCHAR(32) NOT NULL,
	ConsorcioID INT NOT NULL,
	Importe DECIMAL(12,2) NOT NULL CHECK (Importe >= 0),

	CONSTRAINT FK_GastoMensual_Consorcio
		FOREIGN KEY (ConsorcioID)
		REFERENCES infraestructura.Consorcio(ConsorcioID),

	CONSTRAINT UQ_GastoOrdMensual_GastoUnicoPorPeriodo
		UNIQUE (Periodo, Categoria, ConsorcioID)
);
GO


CREATE TABLE contable.Pago(
	PagoID INT IDENTITY(10000,1) PRIMARY KEY,
	Fecha DATE NOT NULL,
	NroClaveUniformeID CHAR(22) NOT NULL,
	Importe DECIMAL(12,2) NOT NULL CHECK (Importe > 0),

	CONSTRAINT FK_Pago_CuentaBancaria
		FOREIGN KEY (NroClaveUniformeID)
		REFERENCES persona.CuentaBancaria(NroClaveUniformeID),
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
    @DNI VARCHAR(12) 
)
RETURNS INT -- cubre 2 puntos y dos digitos mas a los DNI actuales
AS
BEGIN
    DECLARE @DNINorm VARCHAR(20);

    IF @DNI IS NULL -- si es NULL retonramos
        RETURN NULL;

    SET @DNINorm = @DNI;
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

CREATE OR ALTER PROCEDURE general.p_RegistrarLogImportacion
    @NombreImportacion VARCHAR(128),
    @FilasInsertadas INT,
    @FilasDuplicadas INT,
    @FilasCorruptas INT,
	@Detalle VARCHAR(128),
    @MostrarPorConsola BIT
AS
BEGIN
    SET NOCOUNT ON;

	BEGIN TRY
		INSERT INTO general.LogImportaciones(NombreImportacion, FilasInsertadas, FilasDuplicadas, FilasCorruptas, Detalle)
		VALUES (@NombreImportacion, @FilasInsertadas,@FilasDuplicadas, @FilasCorruptas, @Detalle);

		PRINT 'Se ha registrado un log con los detalles de la importacion'

	END TRY
	BEGIN CATCH
		PRINT 'Ha ocurrido un error al intentar registrar el log de la importacion'
	END CATCH

    IF @MostrarPorConsola = 1
    BEGIN
	    PRINT '---------------------------------------------------------------------';
        PRINT CHAR(10) + '>>> Importacion de ' + @NombreImportacion + ' completado:';
		PRINT '		Detalle: ' + @Detalle;
        PRINT '     Inserciones totales: ' + CAST(@FilasInsertadas AS VARCHAR(10));
        PRINT '     Registros duplicados: ' + CAST(@FilasDuplicadas AS VARCHAR(10));
        PRINT '     Registros corruptos: ' + CAST(@FilasCorruptas AS VARCHAR(10));
        PRINT '---------------------------------------------------------------------';
    END
END;
GO
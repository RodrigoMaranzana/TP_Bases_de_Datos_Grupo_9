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

CREATE TABLE infraestructura.Consorcio(
	ConsorcioID INT IDENTITY(1,1) PRIMARY KEY,
	NombreConsorcio VARCHAR(255) NOT NULL,
	Domicilio VARCHAR(255) NOT NULL,
	CantidadUF INT NOT NULL,
	Superficie DECIMAL(6,2) NOT NULL,

	CONSTRAINT CK_Consorcio_CantidadUFValida
        CHECK (CantidadUF > 0),

	CONSTRAINT CK_Consorcio_SuperficieValida
        CHECK (Superficie > 0)
);
GO

CREATE TABLE infraestructura.UnidadFuncional(
	NroUnidadFuncionalID INT,
	ConsorcioID INT NOT NULL,
	Piso CHAR(2) NOT NULL,
	Departamento CHAR(1) NOT NULL,
	Superficie DECIMAL(6,2) NOT NULL,
	TieneBaulera BIT NOT NULL,
	SuperficieBaulera DECIMAL(6,2),
	TieneCochera BIT NOT NULL,
	SuperficieCochera DECIMAL(6,2),
	Coeficiente DECIMAL(2,1) NOT NULL CHECK(Coeficiente > 0),

	CONSTRAINT FK_UnidadFuncional_Consorcio
		FOREIGN KEY (ConsorcioID)
		REFERENCES infraestructura.Consorcio(ConsorcioID),

	CONSTRAINT PK_UnidadFuncional
		PRIMARY KEY (ConsorcioID, NroUnidadFuncionalID),

    CONSTRAINT CK_UnidadFuncional_SuperficieValida
        CHECK (Superficie > 0)
);
GO

CREATE TABLE persona.Persona(
	DNI INT PRIMARY KEY CHECK (DNI > 0),
	Nombre VARCHAR(255),
	Apellido VARCHAR(255),
	Mail VARCHAR(255) NOT NULL,
	Telefono VARCHAR(20) NOT NULL,

	CONSTRAINT CK_Persona_MailValido
        CHECK (Mail LIKE '%_@_%._%'),

	CONSTRAINT CK_Persona_TelefonoValido
        CHECK (Telefono NOT LIKE '%[^0-9]%'),
);
GO

CREATE TABLE persona.CuentaBancaria(
	NroClaveUniformeID CHAR(22) PRIMARY KEY,
	TipoClaveUniforme CHAR(1) NOT NULL CHECK(TipoClaveUniforme IN ('B', 'V')),
	DNI INT NOT NULL,

	CONSTRAINT FK_CuentaBancaria_Persona
		FOREIGN KEY (DNI)
		REFERENCES persona.Persona(DNI),

	CONSTRAINT CK_CuentaBancaria_NroClaveUniformeValido
        CHECK (LEN(NroClaveUniformeID) = 22 AND NroClaveUniformeID NOT LIKE '%[^0-9]%')
);
GO

CREATE TABLE persona.Habitante(
	DNI INT NOT NULL,
	ConsorcioID INT NOT NULL,
	NroUnidadFuncionalID INT NOT NULL,
	EsInquilino BIT NOT NULL,

	CONSTRAINT PK_Habitante
		PRIMARY KEY (DNI, ConsorcioID, NroUnidadFuncionalID),

	CONSTRAINT FK_Habitante_Persona
		FOREIGN KEY (DNI)
		REFERENCES persona.Persona(DNI),

	CONSTRAINT FK_Habitante_UnidadFuncional
		FOREIGN KEY (ConsorcioID, NroUnidadFuncionalID)
		REFERENCES infraestructura.UnidadFuncional(ConsorcioID, NroUnidadFuncionalID)
);
GO

CREATE TABLE persona.ProveedorCategoria(
	CategoriaID INT identity(1,1) PRIMARY KEY,
	Descripcion VARCHAR(32) UNIQUE
);
GO

CREATE TABLE persona.RazonSocial(
	RazonSocialID INT identity(1,1) PRIMARY KEY,
	Nombre VARCHAR(255) UNIQUE
);
GO

CREATE TABLE persona.Proveedor(
	ProveedorID INT identity(1,1) PRIMARY KEY,
	RazonSocialID INT,
	CategoriaID INT NOT NULL,
	DetalleAdicional VARCHAR(255),

	CONSTRAINT FK_Proveedor_RazonSocial
		FOREIGN KEY (RazonSocialID)
		REFERENCES persona.RazonSocial(RazonSocialID),

	CONSTRAINT FK_Proveedor_ProveedorCategoria
		FOREIGN KEY (CategoriaID)
		REFERENCES persona.ProveedorCategoria(CategoriaID),

	CONSTRAINT UQ_Proveedor_ServicioUnico
		UNIQUE (RazonSocialID, CategoriaID, DetalleAdicional)
);
GO

CREATE TABLE persona.ConsorcioProveedor (
    ConsorcioID INT NOT NULL,
    ProveedorID INT NOT NULL,

	CONSTRAINT PK_ConsorcioProveedor
		PRIMARY KEY (ConsorcioID, ProveedorID), 
   
    CONSTRAINT FK_ConsorcioProveedor_Consorcio
        FOREIGN KEY (ConsorcioID)
        REFERENCES infraestructura.Consorcio(ConsorcioID),

    CONSTRAINT FK_ConsorcioProveedor_Proveedor
        FOREIGN KEY (ProveedorID)
        REFERENCES persona.Proveedor(ProveedorID)
);
GO

CREATE TABLE contable.GastoOrdMensual(
	GastoOrdMensualID INT IDENTITY(1,1) PRIMARY KEY,
	Periodo DATE NOT NULL,
	CategoriaID INT NOT NULL,
	ConsorcioID INT NOT NULL,
	Importe DECIMAL(12,2) NOT NULL DEFAULT 0,

	CONSTRAINT FK_GastoOrdMensual_Consorcio
		FOREIGN KEY (ConsorcioID)
		REFERENCES infraestructura.Consorcio(ConsorcioID),

	CONSTRAINT FK_GastoOrdMensualPorCategoria_ProveedorCategoria
		FOREIGN KEY (CategoriaID)
		REFERENCES persona.ProveedorCategoria(CategoriaID),

	CONSTRAINT UQ_GastoOrdMensual_GastoUnicoPorPeriodo
		UNIQUE (Periodo, CategoriaID, ConsorcioID)
);
GO


CREATE TABLE contable.GastoExtraordMensual(
	GastoExtraordMensualID INT IDENTITY(1,1) PRIMARY KEY,
	Periodo DATE NOT NULL,
	ConsorcioID INT NOT NULL,
	Importe DECIMAL(12,2) NOT NULL DEFAULT 0,

	CONSTRAINT FK_GastoExtraordMensual_Consorcio
		FOREIGN KEY (ConsorcioID)
		REFERENCES infraestructura.Consorcio(ConsorcioID),

	CONSTRAINT UQ_GastoExtraordMensual_GastoUnicoPorPeriodo
		UNIQUE (Periodo, ConsorcioID)
);
GO

CREATE TABLE contable.Pago(
	PagoID INT IDENTITY(10000,1) PRIMARY KEY,
	Fecha DATE NOT NULL,
	NroClaveUniformeID CHAR(22),
	Importe DECIMAL(12,2) NOT NULL CHECK (Importe > 0),

	CONSTRAINT FK_Pago_CuentaBancaria
		FOREIGN KEY (NroClaveUniformeID)
		REFERENCES persona.CuentaBancaria(NroClaveUniformeID),
);
GO
/**********************************************************
 * Bases de Datos Aplicada - Comisión 5600
 * GRUPO 09
 *
 * Archivo: 00_CreacionDB.sql
 * Enunciado cumplimentado: Creación de las tablas del proyecto.
 *
 * Integrantes:
 * - Ludmila Daiana Ibarra Sánchez DNI 42537300
 * - Gianluca Ferreyra DNI 46026937
 * - Rodrigo Ezequiel Maranzana DNI 41853030
 *********************************************************/

 -- DEBUG
DROP TABLE IF EXISTS infraestructura.UnidadFuncional;
DROP TABLE IF EXISTS infraestructura.Consorcio;
DROP TABLE IF EXISTS persona.Habitante;
DROP TABLE IF EXISTS persona.CuentaBancariaAsociada;
DROP SCHEMA IF EXISTS infraestructura;
DROP SCHEMA IF EXISTS persona;
DROP SCHEMA IF EXISTS contable;

GO
 -- DEBUG

/**********************************************************
* 
*				   INICIO DE LA SOLUCION 
*
**********************************************************/

--CREATE DATABASE Com5600G09;
--GO

USE Com5600G09;
GO

/**********************************************************
* Esquema para los objetos referidos a todo lo relacionado
* a partes físicas y estructurales del Consorcio.
**********************************************************/
CREATE SCHEMA infraestructura;
GO

/**********************************************************
* Esquema para los objetos referidos a todo lo relacionado
* a habitantes, personas externas y su informacion relacionada.
**********************************************************/
CREATE SCHEMA persona;
GO


/**********************************************************
* Esquema para los objetos referidos a todo lo relacionado
* a la parte monetaria, pagos, deudas, costos y liquidaciones.
**********************************************************/
CREATE SCHEMA contable;
GO



CREATE TABLE infraestructura.Consorcio(
	ConsorcioID VARCHAR(12) PRIMARY KEY, -- Es un varchar mas grande o simplemente un int identity??
	NombreConsorcio VARCHAR(255) NOT NULL,
	Domicilio VARCHAR(255) NOT NULL,
	CantidadUF INT NOT NULL,
	Superficie DECIMAL(6,2) NOT NULL, -- Deberia ser INT??
	CONSTRAINT CK_Consorcio_CantidadUFValida
        CHECK (CantidadUF > 0),
	CONSTRAINT CK_Consorcio_SuperficieValida
        CHECK (Superficie > 0)
);
GO

CREATE TABLE infraestructura.UnidadFuncional(
	NroUnidadFuncional INT,
	ConsorcioID VARCHAR(12) NOT NULL,
	Piso CHAR(2) NOT NULL,
	Departamento CHAR(1) NOT NULL,
	Costo DECIMAL(10,2) NOT NULL, -- Es el costo de expensas de esta unidad?
	Superficie DECIMAL(6,2) NOT NULL,
	TieneBaulera BIT NOT NULL,
	SuperficieBaulera DECIMAL(6,2),
	TieneCochera BIT NOT NULL,
	SuperficieCochera DECIMAL(6,2),
	Coeficiente DECIMAL(2,1) NOT NULL CHECK(Coeficiente > 0),
	-- MailPropietario VARCHAR(255), -- Necesita check!!
	-- TelefonoPropietario VARCHAR(20),
	CONSTRAINT FK_UnidadFuncional_Consorcio
		FOREIGN KEY (ConsorcioID)
		REFERENCES infraestructura.Consorcio(ConsorcioID),
	CONSTRAINT PK_UnidadFuncional
		PRIMARY KEY (ConsorcioID, NroUnidadFuncional),
	CONSTRAINT CK_UnidadFuncional_CostoValido
        CHECK (Costo >= 0),
    CONSTRAINT CK_UnidadFuncional_SuperficieValida
        CHECK (Superficie > 0)
);
GO

CREATE TABLE persona.Habitante(
	DNI INT CHECK (DNI > 0),
	Nombre VARCHAR(255),
	Apellido VARCHAR(255),
	ConsorcioID VARCHAR(12) NOT NULL,
	NroUnidadFuncional INT NOT NULL,
	Mail VARCHAR(255) NOT NULL,
	Telefono VARCHAR(20) NOT NULL,
	NroClaveUniforme CHAR(22) NOT NULL, -- Es FK de contable.CuentaBancariaAsociada
	TipoClaveUniforme CHAR(1) NOT NULL CHECK(TipoClaveUniforme IN ('B', 'V')),
	EsInquilino BIT NOT NULL,
	CONSTRAINT FK_Habitante_UnidadFuncional
		FOREIGN KEY (ConsorcioID, NroUnidadFuncional)
		REFERENCES infraestructura.UnidadFuncional(ConsorcioID, NroUnidadFuncional),
	CONSTRAINT PK_Habitante
		PRIMARY KEY (DNI, Nombre, Apellido),
	CONSTRAINT CK_Habitante_MailValido
        CHECK (Mail LIKE '%_@_%._%'), -- Reemplazar por una funcion (f_EmailValido)
	CONSTRAINT CK_Habitante_TelefonoValido
        CHECK (Telefono NOT LIKE '%[^0-9]%'), -- Reemplazar por una funcion (f_TelefonoValido)
	CONSTRAINT CK_Habitante_NroClaveUniformeValido
        CHECK (LEN(NroClaveUniforme) = 22 AND NroClaveUniforme NOT LIKE '%[^0-9]%') -- Reemplazar por una funcion (f_NroClaveUniformeValido)
);
GO

CREATE TABLE persona.CuentaBancariaAsociada(
	NroClaveUniforme CHAR(22) PRIMARY KEY,
	TipoClaveUniforme CHAR(1) NOT NULL CHECK(TipoClaveUniforme IN ('B', 'V')),
	DNI INT,
	Nombre VARCHAR(255),
	Apellido VARCHAR(255),
	CONSTRAINT FK_CuentaBancariaAsociada_Habitante
		FOREIGN KEY (DNI, Nombre, Apellido)
		REFERENCES persona.Habitante(DNI, Nombre, Apellido),
	CONSTRAINT CK_CuentaBancariaAsociada_NroClaveUniformeValido
        CHECK (LEN(NroClaveUniforme) = 22 AND NroClaveUniforme NOT LIKE '%[^0-9]%') -- Reemplazar por una funcion (f_NroClaveUniformeValido)
);
GO



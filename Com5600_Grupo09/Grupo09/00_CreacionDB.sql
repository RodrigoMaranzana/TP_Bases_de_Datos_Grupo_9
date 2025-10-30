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
DROP SCHEMA IF EXISTS infraestructura;
GO
 -- DEBUG

/**********************************************************
* 
*				   INICIO DE LA SOLUCION 
*
**********************************************************/

--CREATE DATABASE Com5600G09
--GO

USE Com5600G09;
GO

/**********************************************************
* Esquema para los objetos referidos a todo lo relacionado
* a partes físicas y estructurales del Consorcio.
**********************************************************/
CREATE SCHEMA infraestructura
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
)
GO

CREATE TABLE infraestructura.UnidadFuncional(
	NroUnidadFuncional INT,
	ConsorcioID VARCHAR(12) NOT NULL,
	Piso CHAR(2) NOT NULL,
	Departamento CHAR(1) NOT NULL,
	Costo DECIMAL(10,2) NOT NULL, -- Es el costo de expensas de esta unidad?
	Superficie DECIMAL(6,2) NOT NULL, -- Deberia ser INT??
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
)
GO

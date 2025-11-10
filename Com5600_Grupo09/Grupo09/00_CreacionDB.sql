/**********************************************************
 * Bases de Datos Aplicada - Comisión 5600
 * GRUPO 09
 *
 * Archivo: 00_CreacionDB.sql
 * Enunciado cumplimentado: Creación de la base de datos y esquemas del proyecto.
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


/**		Habilita opc. avanzadas y OPENROWSET	 **/

EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;
GO

EXEC sp_configure 'Ad Hoc Distributed Queries', 1; -- habilita consultas con openrowset dentro de los SPs
RECONFIGURE;
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
	/* ELIMINACION DE FUNCIONES Y STORED PROCEDURES */
----------------------------------------------------------------------------------------------------------------------------------

-- eliminamos los SPs
DROP PROCEDURE IF EXISTS importar.p_GenerarLotePagos;
DROP PROCEDURE IF EXISTS importar.p_GenerarGastosExtraordinariosDesdePagos;
DROP PROCEDURE IF EXISTS importar.p_GenerarGastosOrdinariosDesdePagos;
DROP PROCEDURE IF EXISTS importar.p_ImportarGastosOrdinariosJSON;
DROP PROCEDURE IF EXISTS importar.p_ImportarInquilinoPropietarioPorClaveUniformePorUF;
DROP PROCEDURE IF EXISTS importar.p_ImportarPagosConsorcios;
DROP PROCEDURE IF EXISTS importar.p_ImportarDatosVarios;
DROP PROCEDURE IF EXISTS importar.p_ImportarPersonasYCuentasBancarias;
DROP PROCEDURE IF EXISTS importar.p_ImportarUnidadFuncional;
DROP PROCEDURE IF EXISTS general.p_RegistrarLog;
DROP PROCEDURE IF EXISTS general.p_Reporte1ReacaudacionSemanal;
DROP PROCEDURE IF EXISTS general.p_Reporte2RecaudacionMensualPorDepartamento_XML;
DROP PROCEDURE IF EXISTS general.p_Reporte3RecaudacionTotalSegunProcedencia;
DROP PROCEDURE IF EXISTS general.p_Reporte4MayoresGastosEIngresos;
DROP PROCEDURE IF EXISTS general.p_Reporte5PropietariosMorosos;
DROP PROCEDURE IF EXISTS general.p_Reporte6PagosEntreFechas;
DROP PROCEDURE IF EXISTS general.p_Reporte7GraficoDeGastosOrdinariosPorCategoria;
DROP PROCEDURE IF EXISTS contable.p_CalcularProrrateoMensual;
DROP PROCEDURE IF EXISTS contable.p_CalcularEstadoFinanciero;
GO
-- eliminamos las funciones
DROP FUNCTION IF EXISTS general.f_RemoverBlancos;
DROP FUNCTION IF EXISTS general.f_NormalizarTelefono;
DROP FUNCTION IF EXISTS general.f_NormalizarDNI;
DROP FUNCTION IF EXISTS general.f_NormalizarMail;
DROP FUNCTION IF EXISTS general.f_NormalizarImporte;
DROP FUNCTION IF EXISTS general.f_NormalizarFecha_DDMMYYYY;
GO

----------------------------------------------------------------------------------------------------------------------------------
	/* ELIMINACION DE SCHEMAS */
----------------------------------------------------------------------------------------------------------------------------------

--eliminamos los schemas
DROP SCHEMA IF EXISTS importar;
DROP SCHEMA IF EXISTS infraestructura;
DROP SCHEMA IF EXISTS persona;
DROP SCHEMA IF EXISTS contable;
DROP SCHEMA IF EXISTS general;
GO

----------------------------------------------------------------------------------------------------------------------------------
	/* ELIMINACION DE TODA LA BASE DE DATOS */
----------------------------------------------------------------------------------------------------------------------------------

USE master;
GO

IF DB_ID('Com5600G09') IS NOT NULL 
BEGIN -- ponemos a la DB en modo un solo usuario para forzar la desconexion
    ALTER DATABASE Com5600G09 SET SINGLE_USER WITH ROLLBACK IMMEDIATE; 
    DROP DATABASE Com5600G09;
END
GO

----------------------------------------------------------------------------------------------------------------------------------
	/* CREACION DE LA BASE DE DATOS */
----------------------------------------------------------------------------------------------------------------------------------

IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = N'Com5600G09') -- si no existe una base con el nombre Com5600G09 la crea
BEGIN
    CREATE DATABASE Com5600G09
    COLLATE Latin1_General_CI_AI; -- collate elejido, Case Insensitive Accent Insensitive
END
GO

USE Com5600G09;
GO

----------------------------------------------------------------------------------------------------------------------------------
	/* CREACION DE LOS SHCEMAS */
----------------------------------------------------------------------------------------------------------------------------------

----------------------------------------------------------------------------------------------------------------------------------
    /* Esquema para los SP de importación. */
----------------------------------------------------------------------------------------------------------------------------------
CREATE SCHEMA importar;
GO

----------------------------------------------------------------------------------------------------------------------------------
    /* Esquema para los objetos referidos a las partes físicas y estructurales del Consorcio. */
----------------------------------------------------------------------------------------------------------------------------------
CREATE SCHEMA infraestructura;
GO

----------------------------------------------------------------------------------------------------------------------------------
    /* Esquema para los objetos referidos a los habitantes, personas externas y su informacion relacionada. */
----------------------------------------------------------------------------------------------------------------------------------
CREATE SCHEMA persona;
GO

----------------------------------------------------------------------------------------------------------------------------------
    /* Esquema para los objetos referidos a la parte monetaria, pagos, deudas, costos y liquidaciones. */
----------------------------------------------------------------------------------------------------------------------------------
CREATE SCHEMA contable;
GO

----------------------------------------------------------------------------------------------------------------------------------
    /* Esquema para los objetos genericos aprovechables en todas las tablas, como por ejemplo validaciones de tipos */
----------------------------------------------------------------------------------------------------------------------------------
CREATE SCHEMA general;
GO



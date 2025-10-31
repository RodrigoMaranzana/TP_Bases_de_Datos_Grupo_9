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

/**		Eliminación de la Base de Datos	 **/

USE master;
GO

IF DB_ID('Com5600G09') IS NOT NULL
BEGIN
    ALTER DATABASE Com5600G09 SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE Com5600G09;
END
GO

/**		Creación de la Base de Datos	 **/

CREATE DATABASE Com5600G09;
GO

USE Com5600G09;
GO

/**		Creación de Esquemas	 **/


/**
* Esquema para los objetos referidos a todo lo relacionado
* a partes físicas y estructurales del Consorcio.
**/
CREATE SCHEMA infraestructura;
GO

/**
* Esquema para los objetos referidos a todo lo relacionado
* a habitantes, personas externas y su informacion relacionada.
**/
CREATE SCHEMA persona;
GO

/**
* Esquema para los objetos referidos a todo lo relacionado
* a la parte monetaria, pagos, deudas, costos y liquidaciones.
**/
CREATE SCHEMA contable;
GO
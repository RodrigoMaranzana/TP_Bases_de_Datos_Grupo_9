/**********************************************************
 * Bases de Datos Aplicada - Comisión 5600
 * GRUPO 09
 *
 * Archivo: X0_ReconstruirDB.sql
 *
 * Utilizamos este archivo como un acceso directo a la ejecucion
 * de todos los scripts como una herramienta de testing/desarrollo
 *
 * Integrantes:
 * - Ludmila Daiana Ibarra Sánchez DNI 42537300
 * - Gianluca Ferreyra DNI 46026937
 * - Rodrigo Ezequiel Maranzana DNI 41853030
 *********************************************************/

/* Usar el modo SQLCMD (Ubicada en la lista desplegable "Consulta") */

:setvar RutaProyecto "C:\Users\rodri\Development\Bases_de_Datos_Aplicadas\TP_Bases_de_Datos_Grupo_9\Com5600_Grupo09\Grupo09"

USE Com5600G09;
GO

:r $(RutaProyecto)\00_CreacionDB.sql
GO

:r $(RutaProyecto)\01_CreacionObjetos.sql
GO

:r $(RutaProyecto)\02_CreacionSPImportarDatosVarios.sql
GO

:r $(RutaProyecto)\03_CreacionSPImportarInquilinoPropietariosDatos.sql
GO

:r $(RutaProyecto)\04_CreacionSPImportarUFPorConsorcio.sql
GO

:r $(RutaProyecto)\05_CreacionSPImportarInquilinoPropietariosUF.sql
GO

:r $(RutaProyecto)\06_CreacionSPImportarPagosConsorcios.sql
GO

:r $(RutaProyecto)\07_CreacionSPImportarServiciosServicios.sql
GO

:r $(RutaProyecto)\08_CreacionSPGenerarLote.sql
GO

:r $(RutaProyecto)\09_CreacionIDX.sql
GO

:r $(RutaProyecto)\10_CreacionSPReportes.sql
GO

:r $(RutaProyecto)\11_CreacionRoles.sql
GO

--No coloco el script de cifrado para ejecutarlo manualmente cuando queramos
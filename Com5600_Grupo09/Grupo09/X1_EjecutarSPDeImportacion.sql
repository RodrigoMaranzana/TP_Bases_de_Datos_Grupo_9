/**********************************************************
 * Bases de Datos Aplicada - Comisi�n 5600
 * GRUPO 09
 *
 * Archivo: 08_EjecutarSPDeImportacion.sql
 * Enunciado cumplimentado: Creaci�n de script para la importaci�n de maestros
 *
 * Integrantes:
 * - Ludmila Daiana Ibarra S�nchez DNI 42537300
 * - Gianluca Ferreyra DNI 46026937
 * - Rodrigo Ezequiel Maranzana DNI 41853030
 *********************************************************/


----------------------------------------------------------------------------------------------------------------------------------
	/* EJECUCION DE LAS IMPORTACIONES Y GENERACIONES */
----------------------------------------------------------------------------------------------------------------------------------

USE Com5600G09;
GO

EXEC importar.p_ImportarDatosVarios 'C:\Maestros\datos varios.xlsx';
GO
select * from infraestructura.Consorcio;
GO
--select * from persona.Servicio;
GO


EXEC importar.p_ImportarPersonasYCuentasBancarias'C:\Maestros\Inquilino-propietarios-datos.csv';
GO
--select * from persona.Persona;
GO
--select * from persona.CuentaBancaria;
GO


EXEC importar.p_ImportarUnidadFuncional'C:\Maestros\UF por consorcio.txt';
GO
--select * from infraestructura.UnidadFuncional;
GO


EXEC importar.p_ImportarInquilinoPropietarioPorClaveUniformePorUF'C:\Maestros\Inquilino-propietarios-UF.csv';
GO
--select * from infraestructura.UnidadFuncional;
GO


EXEC importar.p_ImportarPagosConsorcios'C:\Maestros\pagos_consorcios.csv';
GO
EXEC importar.p_GenerarLotePagos @Probabilidad = 1;
GO
--select * from contable.Pago;
GO


EXEC importar.p_ImportarGastosOrdinariosJSON'C:\Maestros\Servicios.Servicios.json';
GO
select * from contable.GastoOrdinario;
GO

----------------------------------------------------------------------------------------------------------------------------------
	/* VER LOS LOGS DE IMPORTACIONES */
----------------------------------------------------------------------------------------------------------------------------------

--select * from general.Log;
GO
--select * from general.LogRegistroRechazado;
GO

----------------------------------------------------------------------------------------------------------------------------------
	/* EJECUCION DE LOS REPORTES */
----------------------------------------------------------------------------------------------------------------------------------

--EXEC general.p_Reporte1ReacaudacionSemanal 3, '2025-04-01', '2025-06-30';
GO

--EXEC general.p_Reporte2RecaudacionMensualPorDepartamento_XML 2, 2025, 5;
GO

--EXEC  general.p_Reporte3RecaudacionTotalSegunProcedencia 3, '2025-04-01', '2025-06-15';
GO

--EXEC general.p_Reporte4MayoresGastosEIngresos 1, '2025-04-01', '2025-06-15';
GO

--EXEC  general.p_Reporte5PropietariosMorosos 5, '2025-04-01', '2025-06-15';
GO

--EXEC general.p_Reporte6PagosEntreFechas 4, '2025-04-01', '2025-06-30';
GO

--EXEC general.p_Reporte7GraficoDeGastosOrdinariosPorCategoria @ConsorcioID = 2, @PeriodoAnio = 2025, @PeriodoMes = 4;
GO



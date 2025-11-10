/**********************************************************
 * Bases de Datos Aplicada - Comision 5600
 * GRUPO 09
 *
 * Archivo: Pruebas_EjecutarSPDeImportacion.sql
 * Enunciado cumplimentado: Script de testing para ejecutar
 * los SPs de importacion y de reportes
 *
 * Integrantes:
 * - Ludmila Daiana Ibarra Sanchez DNI 42537300
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
SELECT * FROM infraestructura.Consorcio;
GO
SELECT * FROM persona.Servicio;
GO


EXEC importar.p_ImportarPersonasYCuentasBancarias'C:\Maestros\Inquilino-propietarios-datos.csv';
GO
SELECT * FROM persona.Persona;
GO
SELECT * FROM persona.CuentaBancaria;
GO


EXEC importar.p_ImportarUnidadFuncional'C:\Maestros\UF por consorcio.txt';
GO
SELECT * FROM infraestructura.UnidadFuncional;
GO


EXEC importar.p_ImportarInquilinoPropietarioPorClaveUniformePorUF'C:\Maestros\Inquilino-propietarios-UF.csv';
GO
SELECT * FROM infraestructura.UnidadFuncional;
GO


EXEC importar.p_ImportarPagosConsorcios'C:\Maestros\pagos_consorcios.csv';
GO
IF NOT EXISTS (SELECT 1 FROM contable.Pago WHERE contable.Pago.Concepto = 'EXTRAORDINARIO')
BEGIN -- esto lo realizamos para que los valores de los reportes sean mas variados
	EXEC importar.p_GenerarLotePagos @Probabilidad = 1, @ImporteMax = 10000, @ImporteMin = 1000;
	EXEC importar.p_GenerarGastosExtraordinariosDesdePagos;
END -- solo lo ejecutamos una vez para no incrementar en demasia los pagos
SELECT * FROM contable.Pago;
GO
SELECT * FROM contable.GastoExtraordinario;
GO


EXEC importar.p_ImportarGastosOrdinariosJSON'C:\Maestros\Servicios.Servicios.json';
GO
EXEC importar.p_GenerarGastosOrdinariosDesdePagos;
GO
SELECT * FROM contable.GastoOrdinario;
GO


EXEC contable.p_CalcularProrrateoMensual '2025-4-1';
GO
EXEC contable.p_CalcularProrrateoMensual '2025-5-1';
GO
EXEC contable.p_CalcularProrrateoMensual '2025-6-1';
GO
SELECT * FROM contable.Prorrateo;
GO


EXEC contable.p_CalcularEstadoFinanciero '2025-4-1';
GO
EXEC contable.p_CalcularEstadoFinanciero '2025-5-1';
GO
EXEC contable.p_CalcularEstadoFinanciero '2025-6-1';
GO
SELECT * FROM contable.EstadoFinanciero
GO

----------------------------------------------------------------------------------------------------------------------------------
	/* VER LOS LOGS DE IMPORTACIONES */
----------------------------------------------------------------------------------------------------------------------------------

SELECT * FROM general.Log;
GO
SELECT * FROM general.LogRegistroRechazado;
GO

----------------------------------------------------------------------------------------------------------------------------------
	/* EJECUCION DE LOS REPORTES */
----------------------------------------------------------------------------------------------------------------------------------

EXEC general.p_Reporte1ReacaudacionSemanal 3, '2025-04-01', '2025-06-30';
GO

EXEC general.p_Reporte2RecaudacionMensualPorDepartamento_XML 2, 2025, 5;
GO

EXEC  general.p_Reporte3RecaudacionTotalSegunProcedencia 3, '2025-04-01', '2025-06-15';
GO

EXEC general.p_Reporte4MayoresGastosEIngresos 1, '2025-04-01', '2025-06-15';
GO

EXEC  general.p_Reporte5PropietariosMorosos 4, '2025-04-01', '2025-06-15';
GO

EXEC general.p_Reporte6PagosEntreFechas 4, '2025-04-01', '2025-06-30';
GO

EXEC general.p_Reporte7GraficoDeGastosOrdinariosPorCategoria @ConsorcioID = 2, @PeriodoAnio = 2025, @PeriodoMes = 4;
GO



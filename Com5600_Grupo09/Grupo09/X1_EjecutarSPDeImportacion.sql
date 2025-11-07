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


USE Com5600G09;
GO

EXEC importar.p_ImportarDatosVarios 'C:\Maestros\datos varios.xlsx';
GO
select * from infraestructura.Consorcio;
GO
select * from persona.Servicio;
GO


EXEC importar.p_ImportarPersonasYCuentasBancarias'C:\Maestros\Inquilino-propietarios-datos.csv';
GO
select * from persona.Persona;
GO
select * from persona.CuentaBancaria;
GO


EXEC importar.p_ImportarUnidadFuncional'C:\Maestros\UF por consorcio.txt';
GO
select * from infraestructura.UnidadFuncional;
GO

EXEC importar.p_ImportarInquilinoPropietarioPorClaveUniformePorUF'C:\Maestros\Inquilino-propietarios-UF.csv';
GO
select * from infraestructura.UnidadFuncional;
GO

EXEC importar.p_ImportarPagosConsorcios'C:\Maestros\pagos_consorcios.csv';
GO
select * from contable.Pago;
GO

EXEC general.p_ReporteMayoresGastosEIngresos 2, '2025-04-01', '2025-06-15';
GO


EXEC general.p_ReporteReacaudacionSemanal 3, '2024-04-01', '2024-06-30';
GO

EXEC general.p_ReporteRecaudacionTotalSegunProcedencia 5, '2024-04-01', '2024-06-30';
GO


/*
EXEC importar.p_ImportarGastosOrdinariosJSON'C:\Maestros\Servicios.Servicios.json';
GO
select * from contable.GastoOrdinario;
GO

EXEC importar.p_GenerarLotePagos;
GO
*/

select * from general.Log;
GO
select * from general.LogRegistroRechazado;
GO
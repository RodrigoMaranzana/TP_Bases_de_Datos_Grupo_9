/**********************************************************
 * Bases de Datos Aplicada - Comisión 5600
 * GRUPO 09
 *
 * Archivo: 08_EjecutarSPDeImportacion.sql
 * Enunciado cumplimentado: Creación de script para la importación de maestros
 *
 * Integrantes:
 * - Ludmila Daiana Ibarra Sánchez DNI 42537300
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
select * from persona.Propietario;
GO
select * from persona.Inquilino;
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

select * from general.Log;
GO

select * from general.LogRegistroRechazado;
GO
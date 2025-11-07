/**********************************************************
 * Bases de Datos Aplicada - Comisi�n 5600
 * GRUPO 09
 *
 * Archivo: 09_CreacionIDX.sql
 * Enunciado cumplimentado: Crecion de indices para los reportes
 *
 * Integrantes:
 * - Ludmila Daiana Ibarra Sanchez DNI 42537300
 * - Gianluca Ferreyra DNI 46026937
 * - Rodrigo Ezequiel Maranzana DNI 41853030
 *********************************************************/

USE Com5600G09;
GO

-- Indices para optimizar las consultas de los reportes

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Pago_Fecha')
BEGIN
CREATE NONCLUSTERED INDEX IX_Pago_Fecha
ON contable.Pago (Fecha)
INCLUDE (NroClaveUniformeID, Importe, Concepto);
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_CuentaBancaria_PersonaID')
BEGIN
CREATE NONCLUSTERED INDEX IX_CuentaBancaria_PersonaID 
ON persona.CuentaBancaria (PersonaID)
INCLUDE (NroClaveUniformeID);
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_UnidadFuncional_PropietarioID')
BEGIN
CREATE NONCLUSTERED INDEX IX_UnidadFuncional_PropietarioID 
ON infraestructura.UnidadFuncional (PropietarioID) 
INCLUDE (ConsorcioID, Piso, Departamento);
END
GO


IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_UnidadFuncional_InquilinoID')
BEGIN
CREATE NONCLUSTERED INDEX IX_UnidadFuncional_InquilinoID 
ON infraestructura.UnidadFuncional (InquilinoID) 
INCLUDE (ConsorcioID, Piso, Departamento);
END
GO


IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_GastoExtraordinario_Periodo_Consorcio')
BEGIN
CREATE NONCLUSTERED INDEX IX_GastoExtraordinario_Periodo_Consorcio
ON contable.GastoExtraordinario (ConsorcioID, Periodo)
INCLUDE (Importe);
END
GO


IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_GastoOrdinario_Consorcio_Periodo')
BEGIN
CREATE NONCLUSTERED INDEX IX_GastoOrdinario_Consorcio_Periodo
ON contable.GastoOrdinario (ConsorcioID, Periodo)
INCLUDE (Importe);
END
GO









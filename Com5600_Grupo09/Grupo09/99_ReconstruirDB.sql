
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
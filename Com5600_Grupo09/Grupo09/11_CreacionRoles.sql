/**********************************************************
 * Bases de Datos Aplicada - Comisión 5600
 * GRUPO 09
 *
 * Archivo: 11_CreacionRoles.sql
 * Enunciado cumplimentado: Creación de los roles del proyecto.
 *
 * Integrantes:
 * - Ludmila Daiana Ibarra Sánchez DNI 42537300
 * - Gianluca Ferreyra DNI 46026937
 * - Rodrigo Ezequiel Maranzana DNI 41853030
 *********************************************************/

USE Com5600G09;
GO

----------------------------------------------------------------------------------------------------------------------------------
	/* CREACION DE ROLES */
----------------------------------------------------------------------------------------------------------------------------------

IF NOT EXISTS (SELECT 1 FROM sys.database_principals 
WHERE name = 'Administrativo General' AND type = 'R')
BEGIN
    CREATE ROLE [Administrativo General];
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.database_principals 
WHERE name = 'Administrativo General' AND type = 'R')
BEGIN
    CREATE ROLE [Administrativo Bancario];
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.database_principals 
WHERE name = 'Administrativo General' AND type = 'R')
BEGIN
    CREATE ROLE [Administrativo Operativo];
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.database_principals 
WHERE name = 'Administrativo General' AND type = 'R')
BEGIN
    CREATE ROLE [Sistemas];
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.database_principals 
WHERE name = 'Administrativo General' AND type = 'R')
BEGIN
    CREATE ROLE [Actualizador de Datos UF];
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.database_principals 
WHERE name = 'Administrativo General' AND type = 'R')
BEGIN
    CREATE ROLE [Importador de Informacion Bancaria];
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.database_principals 
WHERE name = 'Administrativo General' AND type = 'R')
BEGIN
    CREATE ROLE [Generador De Reportes];
END
GO

----------------------------------------------------------------------------------------------------------------------------------
	/* ASIGNACION DE PERMISOS */
----------------------------------------------------------------------------------------------------------------------------------

/** Generador De Reportes **/

GRANT EXECUTE ON general.p_RegistrarLog TO [Generador De Reportes];
GRANT EXECUTE ON general.p_Reporte1ReacaudacionSemanal TO [Generador De Reportes];
GRANT EXECUTE ON general.p_Reporte2RecaudacionMensualPorDepartamento_XML TO [Generador De Reportes];
GRANT EXECUTE ON general.p_Reporte3RecaudacionTotalSegunProcedencia TO [Generador De Reportes];
GRANT EXECUTE ON general.p_Reporte4MayoresGastosEIngresos TO [Generador De Reportes];
GRANT EXECUTE ON general.p_Reporte5PropietariosMorosos TO [Generador De Reportes];
GRANT EXECUTE ON general.p_Reporte6PagosEntreFechas TO [Generador De Reportes];
GRANT EXECUTE ON general.p_Reporte7GraficoDeGastosOrdinariosPorCategoria TO [Generador De Reportes];

/** Importador de Informacion Bancaria **/

GRANT EXECUTE ON importar.p_ImportarPersonasYCuentasBancarias TO [Importador de Informacion Bancaria];
GRANT EXECUTE ON importar.p_ImportarPagosConsorcios TO [Importador de Informacion Bancaria];
GRANT EXECUTE ON importar.p_ImportarGastosOrdinariosJSON TO [Importador de Informacion Bancaria];
GRANT EXECUTE ON importar.p_GenerarLotePagos TO [Importador de Informacion Bancaria];

/** Actualizador de Datos UF **/

GRANT EXECUTE ON contable.p_CalcularProrrateoMensual TO [Actualizador de Datos UF];
GRANT EXECUTE ON importar.p_ImportarDatosVarios TO [Actualizador de Datos UF];
GRANT EXECUTE ON importar.p_ImportarUnidadFuncional TO [Actualizador de Datos UF];
GRANT EXECUTE ON importar.p_ImportarInquilinoPropietarioPorClaveUniformePorUF TO [Actualizador de Datos UF];


/** HERENCIA DE ROLES **/

ALTER ROLE [Generador De Reportes] ADD MEMBER [Administrativo General];
ALTER ROLE [Generador De Reportes] ADD MEMBER [Administrativo Bancario];
ALTER ROLE [Generador De Reportes] ADD MEMBER [Administrativo Operativo];
ALTER ROLE [Generador De Reportes] ADD MEMBER [Sistemas];

ALTER ROLE [Actualizador de Datos UF] ADD MEMBER [Administrativo General];
ALTER ROLE [Actualizador de Datos UF] ADD MEMBER [Administrativo Operativo];

ALTER ROLE [Importador de Informacion Bancaria] ADD MEMBER [Administrativo Bancario];

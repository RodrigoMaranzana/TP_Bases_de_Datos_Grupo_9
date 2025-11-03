## Trabajo Práctico Integrador - Grupo 09
##### Bases de Datos Aplicadas

### Integrantes:

| Nombre y Apellido            | Nick de GitHub   |
| ---------------------------- | ---------------- |
| Ludmila Daiana Ibarra Sáchez | DaianaIbarra     |
| Gianluca Ferreyra            | GianProgrammer   |
| Rodrigo Ezequiel Maranzana   | RodrigoMaranzana |
### Aspectos técnicos del proyecto:
##### Entorno:

- SQL Server 16.0.1150
- SQL Server Management Studio 19.3
- Editor de MarkDown: `Obsidian`
- Sistema operativo:
    - `Windows 11 64bits` (`On-premise`)
    - `Windows 10 64bits` (`Oracle VirtualBox`)

> [!WARNING]
> Se presentaron problemas de incompatibilidad con `Microsoft.ACE.OLEDB.16.0` y `Microsoft.ACE.OLEDB.12.0` cuando se intentó utilizar el modo InProcess mientras se tiene intalada alguna versión moderna de Office con instalador `Click and Run`.
> Se logró utilizar `OLEDB` tanto `12.0` como `16.0` para la importación de archivos .xlsx utilizando una máquina virtual sin instalación del paquete de office, con la instalación  de `Microsoft Access 2016 Runtime` y la correcta habilitación de permisos para el servicio de nuestra instancia de SQL Server dentro de `services.msc`.
> Sin la anterior habilitación de servicios, la ejecución de `OPENROWSET` fallará ya que el proveedor OLEDB arrojará el siguiente error:
> ```
> The OLE DB provider "Microsoft.Ace.OLEDB.12.0" for linked server "(null)" reported an error. Access denied.
>```
> Se adjunta la fuente donde la solución a dicho error se encuentra documentada: [LINK](https://www.aspsnippets.com/Articles/96/The-OLE-DB-provider-Microsoft.Ace.OLEDB.12.0-for-linked-server-null/)


#### Norma de nomenclatura utilizada:

##### Tables:

| Reglas       | Formato                    | Ejemplo                         |
| ------------ | -------------------------- | ------------------------------- |
| Nomenclatura | `PascalCase` (en singular) | `Consorcio` - `UnidadFuncional` |

##### Columns:

| Tipo              | Formato                                 | Ejemplo                                     |
| ----------------- | --------------------------------------- | ------------------------------------------- |
| Nomenclatura base | `PascalCase` (en singular)              | `NumeroFactura`                             |
| Primary Key       | `PascalCase` (en singular) + 'ID'       | `PropietarioID`                             |
| Foreing Key       | `PascalCase` (en singular) + 'ID'       | `UnidadFuncionalID`                         |
| Boolean           | \<Verbo\>  + `PascalCase` (en singular) | `EsInquilino` - `TieneCochera` - `EstaPago` |

##### Stored Procedures:

| Tipo         | Formato                         | Ejemplo                                    |
| ------------ | ------------------------------- | ------------------------------------------ |
| Nomenclatura | 'p_' + \<Verbo\> + `PascalCase` | `p_GenerarExpensas` - `p_ImportarCSVPagos` |
##### Views:

| Tipo         | Formato              | Ejemplo                 |
| ------------ | -------------------- | ----------------------- |
| Nomenclatura | 'v_'  + `PascalCase` | `v_PropietariosMorosos` |

###### Functions:

| Tipo         | Formato                           | Ejemplo             |
| ------------ | --------------------------------- | ------------------- |
| Nomenclatura | 'f_' + `PascalCase` (en singular) | `f_CalcularInteres` |

##### Constraints:

| Tipo        | Formato                                                             | Ejemplo                          |
| ----------- | ------------------------------------------------------------------- | -------------------------------- |
| Primary Key | 'PK_' + \<NombreTabla\>                                             | `PK_UnidadFuncional`             |
| Foreign Key | 'FK_' + \<NombreTablaActual\> + '\_'  + \<NombreTablaReferenciada\> | `FK_UnidadFuncional_Propietario` |
| Check       | 'CK_' + \<NombreTabla\> + \<Condición\>                             | `CK_Propietario_EmailValido`     |
| Unique      | 'UQ_' + \<NombreTabla\> + \<Columna\>                               | `UQ_UnidadFuncional_Numero`      |
##### Indexes:

| Tipo         | Formato                                                           | Ejemplo                                     |
| ------------ | ----------------------------------------------------------------- | ------------------------------------------- |
| Nomenclatura | 'IX_' + \<NombreTabla\> + '\_'  + \<Columna\> + ... + \<Columna\> | `IX_UnidadFuncional_PropietarioID_NroDepto` |

##### Schemas:

| Tipo         | Formato     | Ejemplo    |
| ------------ | ----------- | ---------- |
| Nomenclatura | `lowercase` | `finanzas` |

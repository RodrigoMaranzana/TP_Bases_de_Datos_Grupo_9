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

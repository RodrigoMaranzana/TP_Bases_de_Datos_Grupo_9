/**********************************************************
 * Bases de Datos Aplicada - Comision 5600
 * GRUPO 09
 *
 * Archivo: 13_PoliticaDeRespaldo.sql
 * Enunciado cumplimentado: Implementacion de politicas de respaldo.
 *
 * Integrantes:
 * - Ludmila Daiana Ibarra Sanchez DNI 42537300
 * - Gianluca Ferreyra DNI 46026937
 * - Rodrigo Ezequiel Maranzana DNI 41853030
 *********************************************************/

/**

-- Política de Respaldo propuesta --

  Para asegurar la disponibilidad e integridad de los datos del sistema de expensas de consorcios, los cuales son criticos
para el negocio, proponemos una estrategia de respaldo mixta que se basa en el modelo de recuperación Full, el cual permite
registrar todas las transacciones y posibilita la restauracion de la base de datos en un momento especifico. 
  Esta propuesta combina la realizacion de Backups Completos, que crean una copia completa de la base de datos, Backups Diferenciales
que crean una copia de los datos que han cambiado desde el ultimo backup completo y Backups de Log de Transacciones que crean
una copia del registro de transacciones permitiendo restauraciones granulares.


-- Programación de Backups --

  Se propone realizar Backups Completos (FULL) semanalmente, preferentemente, durante horario nocturno.
Backups Diferenciales a diario durante el horario nocturno y Backups de Log de Transacciones cada 30 minutos durante horas laborales.


-- Indicación de RPO (Recovery Poin Objetive) --

  Con la programacion de respaldos de la base de datos antes mencionada, se establece un RPO de 30 miinutos. Es decir, la cantidad maxima 
de datos que cada consorcio esta dispuesto a perder medido en tiempo. 
Al realizar copias del Log de Transacciones cada 30 minutos, en el peor de los casos, la perdida de datos estará limitada a un maximo
de 30 minutos de operaciones. Lo que consideramos adecuado, para un sistema de consorcios donde se registran pagos o se generan expensas de
inquilinos/propietarios, ya que hay pocas operaciones sobre la base por hora.

  Con esta estrategia de respaldo mantenemos protegidos los datos criticos del negocio, ya que al realizar backups de log cada 30 minutos
garantizamos un RPO bajo, protegiendo la informacion necesaria para la realizacion de calculos de las expensas, pagos registrados, intereses 
y deudas. Perder esta informacion supondria daños criticos e inaceptables para la organizacion.
  El uso de Backups Diferenciales (RTO) acelera el tiempo de restauración en caso de que se genere algun percanse catastrofico en el sistema, ya que
para restaurar la base de datos se necesitaria restaurar el ultimo backup full semanal, el ultimo backup diferencial y aplicar los logs de
30 minutos hasta el momento de la falla, lo cual genera una eficiencia en la restauracion. De otro modo, sin los respaldos diferenciales se tendria
que aplicar cientos de backups de logs correspondientes a toda la semana lo cual seria un proceso mas lento y propenso a errores. 

  Por otra parte, esta propuesta busca la eficiencia de los recursos, ya que realizar un backup completo es una operacion intensiva. Al hacerlo solo 
una vez por semana en un horario de bajo impacto para la organizacion, libera los recursos del servidor. Los backups diferenciales y de log de transacciones
son operaciones mucho mas rápidas que pueden ejecutarse en horarios operativos de la organizacion, es decir, de forma mas frecuente y sin afectar o degradar
el rendimiento del sistema.
  Adicionalmente, consideramos que los backups no deben almacanarse en el mismo servidor fisico que la base de datos y siguiendo la estrategia 3-2-1 de Buenas Prácticas,
se deberian realizar 3 copias de los datos en 2 tipos de medios distintos y con almenos 1 copia fuera del entorno, es decir, en la nube. Ademas, esta politica
de respaldos debe ser sometida a pruebas para que el plan este completo, por ejemplo, proponemos generar un entorno de pruebas trimestralmente para garantizar 
la integridad de los backups realizados y ante una eventual falla o catastrofe en el sistema pueda reaalizarse de forma efectiva y segura la restauracion de la
base de datos. 


**/
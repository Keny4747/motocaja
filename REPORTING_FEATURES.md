# MotoCaja - Resumen y PDF

## Periodos

- Dia: desde 00:00 del dia seleccionado hasta 00:00 del dia siguiente.
- Semana: semana calendario de lunes a domingo que contiene la fecha seleccionada.
- Mes: desde el primer dia del mes hasta el primer dia del mes siguiente.

Todos los rangos usan `fecha >= inicio && fecha < fin`, por lo que no es necesario manejar manualmente meses de 28, 29, 30 o 31 dias.

En Resumen el usuario puede navegar con flechas al periodo anterior/siguiente y tocar el rango para elegir directamente:

- un dia concreto;
- cualquier fecha dentro de la semana que quiere consultar (MotoCaja resuelve automaticamente el lunes y domingo correspondientes);
- un mes concreto mediante selector de mes y ano.

La navegacion hacia adelante se detiene en el periodo actual para evitar reportes futuros vacios. Al cambiar entre Dia, Semana y Mes se conserva la fecha de referencia.

## Promedio diario

El promedio se calcula como:

`ganancia / dias trabajados`

Un dia trabajado es un dia que contiene al menos un ingreso/servicio. Si no hay dias trabajados, el promedio es 0.

## PDF

Dia, Semana y Mes permiten exportar PDF. El documento adapta titulo, rango y nombre del archivo al periodo seleccionado e incluye:

- ingresos
- gastos
- ganancia
- cantidad de servicios
- dias trabajados y promedio diario en Semana/Mes
- movimientos del periodo
- fecha de cada movimiento cuando el reporte abarca varios dias
- ingresos por medio de pago
- gastos por categoria

Se comparte con el selector nativo de Android usando `Printing.sharePdf`.

## Dependencias

- `pdf: ^3.13.0`
- `printing: ^5.15.0`

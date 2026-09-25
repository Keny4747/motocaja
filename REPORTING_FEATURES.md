# MotoCaja - Resumen y PDF

## Periodos

- Dia: desde 00:00 del dia seleccionado hasta 00:00 del dia siguiente.
- Semana: 7 dias incluyendo la fecha seleccionada (fecha seleccionada y los 6 dias anteriores).
- Mes: desde el primer dia del mes hasta el primer dia del mes siguiente.

Todos los rangos usan `fecha >= inicio && fecha < fin`, por lo que no es necesario manejar manualmente meses de 28, 29, 30 o 31 dias.

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

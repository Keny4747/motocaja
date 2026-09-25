# MotoCaja - Deteccion de pagos Yape y Plin

## Que hace

- Escucha la aplicacion oficial de Yape y notificaciones de entidades que pueden operar con Plin.
- Yape: `com.bcp.innovacxion.yapeapp`.
- Incluye paquetes conocidos de BBVA, Interbank, Interbank Negocios, Scotiabank, BanBif, Caja Arequipa, Caja Ica, Caja Huancayo, Financiera Confianza, Alfin Banco, Ligo, Mibanco y Banco Pichincha.
- Tambien usa el nombre visible de la aplicacion como pista para entidades Plin conocidas. Esto ayuda cuando una entidad cambia el package de su app.
- Lee varios campos estandar de Android (`title`, `text`, `bigText`, `subText`, `summaryText`, `infoText` y `textLines`) y contexto adicional de la notificacion (`channelId`, `category`, `group` y `tag`).
- Un aviso solo se propone como cobro cuando contiene una senal explicita de dinero recibido y un monto valido.
- Tener solamente la palabra `Plin` y un monto ya no basta para marcar un ingreso. Esto evita confundir confirmaciones tardias de un Plin enviado con dinero recibido.
- Nunca registra automaticamente: el usuario debe pulsar **Registrar**.
- El ingreso confirmado se guarda en SQLite como `Servicio / Yape` o `Servicio / Plin`.
- MotoCaja conserva los ultimos identificadores procesados para evitar registros duplicados.

## Diagnostico V3

MotoCaja guarda localmente las ultimas 12 notificaciones candidatas de pago. Cada evento registra:

- hora en que MotoCaja lo observo;
- `postTime` entregado por Android;
- fuente, package y nombre visible de la app;
- titulo, texto y detalles recibidos;
- canal, categoria y tag cuando existen;
- monto interpretado, si pudo extraerse;
- decision del parser y motivo de descarte o deteccion.

El historial se consulta en **Configuracion > Pagos inteligentes > Diagnostico de pagos** y puede limpiarse antes de una prueba. No se envia a ningun servidor.

## Activacion

1. Abrir MotoCaja > Configuracion > Pagos inteligentes.
2. Activar **Detectar pagos de Yape y Plin**.
3. Conceder permiso para que MotoCaja muestre notificaciones, si Android lo solicita.
4. En la pantalla del sistema, activar **MotoCaja - Detector de pagos**.
5. Volver a MotoCaja y confirmar que `Acceso a notificaciones` dice `Concedido por Android`.

## Prueba recomendada para Plin

1. Instalar la version nueva y desactivar/activar una vez el acceso a notificaciones de MotoCaja para reconectar el listener.
2. Abrir **Diagnostico de pagos** y pulsar **Limpiar**.
3. No realizar un Plin saliente durante esta prueba.
4. Enviar un unico Plin entrante hacia la cuenta afiliada a Plin del telefono de prueba.
5. Revisar inmediatamente el diagnostico.
6. Si aparece `Detectada`, debe mostrarse la sugerencia **Pago Plin detectado** con **Registrar** e **Ignorar**.
7. Si aparece `Ignorada`, usar el motivo, package, texto y canal para ajustar el parser de esa entidad.
8. Si no aparece ningun evento, revisar que la app bancaria tenga habilitadas sus notificaciones push de abonos/Plin. Un NotificationListener de Android no puede detectar un cobro si la entidad no publica una notificacion en el dispositivo.

## Sobre notificaciones tardias

MotoCaja no contiene un temporizador de un minuto para Plin. La ventana de dos minutos del listener solo evita procesar dos veces la misma notificacion. Si aparece otro aviso aproximadamente un minuto despues, se trata de una nueva notificacion publicada por la app origen. El historial V3 permite comprobarlo comparando package, `postTime`, texto y decision de cada evento.


## Captura temporal V4

Si un Plin real no aparece en el diagnostico normal, usar:

Configuracion > Pagos inteligentes > Capturar Plin por 2 minutos

Durante esa ventana MotoCaja guarda localmente las notificaciones externas antes de aplicar filtros de banco o texto. La captura expira sola. Luego abrir Diagnostico de pagos para revisar package, app, titulo, texto, canal y hora.

La V4 tambien reconoce variantes como `te ha plineado`, `te han plineado`, `te plineo` y `te plinearon`, y tolera errores al leer extras personalizados de apps bancarias.

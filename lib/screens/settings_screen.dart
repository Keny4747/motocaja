import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../database/app_database.dart';
import '../services/app_state.dart';
import '../services/backup_service.dart';
import '../services/notification_service.dart';
import '../services/yape_notification_service.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with WidgetsBindingObserver {
  bool _yapeDetectionEnabled = false;
  bool _yapeAccessGranted = false;
  YapeDiagnostic? _lastYapeDiagnostic;
  bool _dataOperationInProgress = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    YapeNotificationService.instance.initialize();
    _refreshYapeStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshYapeStatus();
    }
  }

  Future<void> _refreshYapeStatus() async {
    try {
      final enabled = await YapeNotificationService.instance
          .getDetectionEnabled();
      final access = await YapeNotificationService.instance
          .isNotificationAccessGranted();
      final diagnostic = await YapeNotificationService.instance
          .getLastDiagnostic();
      if (!mounted) return;
      setState(() {
        _yapeDetectionEnabled = enabled;
        _yapeAccessGranted = access;
        _lastYapeDiagnostic = diagnostic;
      });
    } catch (_) {
      // Mantener Configuración operativa aunque el bridge nativo no esté listo.
    }
  }

  Future<String?> _ask(BuildContext context, String title, String current) {
    return showDialog<String>(
      context: context,
      builder: (_) => _TextSettingDialog(title: title, initialValue: current),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
        children: [
          const Center(
            child: Text(
              'Configuración',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: AppColors.navy,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const _Header('Mi perfil'),
          Row(
            children: [
              Expanded(
                child: _SettingTile(
                  icon: Icons.person,
                  title: state.name,
                  onTap: () async {
                    final value = await _ask(context, 'Nombre', state.name);
                    if (value?.isNotEmpty == true && context.mounted) {
                      await context.read<AppState>().updateProfile(
                        newName: value,
                      );
                    }
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SettingTile(
                  icon: Icons.two_wheeler,
                  title: state.vehicle,
                  onTap: () async {
                    final value = await _ask(
                      context,
                      'Vehículo',
                      state.vehicle,
                    );
                    if (value?.isNotEmpty == true && context.mounted) {
                      await context.read<AppState>().updateProfile(
                        newVehicle: value,
                      );
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const _Header('Preferencias'),
          _SettingTile(
            icon: Icons.percent,
            title: 'Tarifas frecuentes',
            subtitle: _ratesSubtitle(state.frequentRates),
            onTap: () => _frequentRatesDialog(context, state),
          ),
          _SettingTile(
            icon: Icons.credit_card,
            title: 'Método de pago predeterminado',
            subtitle: state.defaultPayment,
            onTap: () => _paymentSheet(context, state),
          ),
          const SizedBox(height: 16),
          const _Header('Recordatorios'),
          _SettingTile(
            icon: Icons.notifications_active_outlined,
            title: 'Activar notificaciones',
            subtitle: 'Se solicita permiso y enviar un aviso de prueba',
            onTap: () => _testNotifications(context),
          ),
          const SizedBox(height: 8),
          _SwitchTile(
            icon: Icons.timer_outlined,
            title: 'Recordarme si dejo de registrar',
            value: state.remindIncome,
            onChanged: (value) =>
                _changeInactivityReminder(context, state, value),
          ),
          const SizedBox(height: 8),
          _SettingTile(
            icon: Icons.schedule_outlined,
            title: 'Tiempo sin movimientos',
            subtitle: _intervalLabel(state.reminderIntervalMinutes),
            onTap: () => _intervalSheet(context, state),
          ),
          const SizedBox(height: 8),
          _SwitchTile(
            icon: Icons.nights_stay_outlined,
            title: 'Recordarme cerrar mi día',
            value: state.remindClose,
            onChanged: (value) => _changeCloseReminder(context, state, value),
          ),
          const SizedBox(height: 8),
          _SettingTile(
            icon: Icons.alarm_outlined,
            title: 'Hora de cierre',
            subtitle: _formatTime(context, state.closeHour, state.closeMinute),
            onTap: () => _pickCloseTime(context, state),
          ),
          const SizedBox(height: 8),
          const _InfoCard(
            text:
                'El recordatorio por inactividad solo se programa si ya '
                'registraste al menos un movimiento y cae entre 7:00 a. m. '
                'y 8:30 p. m.',
          ),
          const SizedBox(height: 16),
          const _Header('Pagos inteligentes'),
          _SwitchTile(
            icon: Icons.account_balance_wallet_outlined,
            title: 'Detectar pagos de Yape y Plin',
            value: _yapeDetectionEnabled,
            onChanged: (value) => _changeYapeDetection(context, value),
          ),
          const SizedBox(height: 8),
          _SettingTile(
            icon: _yapeAccessGranted
                ? Icons.verified_user_outlined
                : Icons.admin_panel_settings_outlined,
            title: 'Acceso a notificaciones',
            subtitle: _yapeAccessGranted
                ? 'Concedido por Android'
                : 'Toca aquí para habilitarlo en Android',
            onTap: _openYapeAccessSettings,
          ),
          const SizedBox(height: 8),
          const _InfoCard(
            text:
                'MotoCaja observa Yape y notificaciones de entidades compatibles '
                'con Plin cuando activas esta función. El contenido se procesa en '
                'el teléfono; no se envía a ningún servidor. Antes de guardar un '
                'ingreso siempre te pediremos confirmación.',
          ),
          const SizedBox(height: 8),
          _SettingTile(
            icon: Icons.troubleshoot_outlined,
            title: 'Diagnóstico de pagos',
            subtitle:
                _lastYapeDiagnostic == null || _lastYapeDiagnostic!.isEmpty
                ? 'Aún no hay una notificación compatible para revisar'
                : 'Toca para ver las últimas notificaciones candidatas',
            onTap: _showLastYapeDiagnostic,
          ),
          const SizedBox(height: 8),
          _SettingTile(
            icon: Icons.radar_outlined,
            title: 'Capturar Plin por 2 minutos',
            subtitle:
                'Modo de diagnóstico: registra temporalmente las notificaciones que aparezcan',
            onTap: _startRawPaymentCapture,
          ),
          const SizedBox(height: 16),
          const _Header('Datos y respaldo'),
          _SettingTile(
            icon: Icons.backup_outlined,
            title: 'Crear respaldo',
            subtitle: 'Movimientos, perfil, tarifas y preferencias',
            onTap: _dataOperationInProgress
                ? null
                : () => _exportBackup(context, state),
          ),
          const SizedBox(height: 8),
          _SettingTile(
            icon: Icons.settings_backup_restore_rounded,
            title: 'Restaurar respaldo',
            subtitle: 'Reemplaza los datos actuales con un archivo de MotoCaja',
            onTap: _dataOperationInProgress
                ? null
                : () => _restoreBackup(context, state),
          ),
          const SizedBox(height: 8),
          const _InfoCard(
            text:
                'El respaldo es un archivo local. Contiene información financiera; guárdalo en un lugar seguro. Restaurarlo reemplaza los movimientos actuales.',
          ),
          if (kDebugMode) ...[
            const SizedBox(height: 16),
            const _Header('Tutorial'),
            const SizedBox(height: 8),
            _SettingTile(
              icon: Icons.replay_rounded,
              title: 'Repetir onboarding',
              subtitle: '',
              onTap: () => _resetOnboardingForDebug(context, state),
            ),
          ],
          const SizedBox(height: 16),
          const _Header('Acerca de'),
          const _SettingTile(
            icon: Icons.info_outline,
            title: 'Acerca de MotoCaja',
            subtitle: 'Versión 1.0.0',
          ),
        ],
      ),
    );
  }

  Future<void> _exportBackup(BuildContext context, AppState state) async {
    setState(() => _dataOperationInProgress = true);

    try {
      final backup = state.createBackupData(
        yapeDetectionEnabled: _yapeDetectionEnabled,
      );
      final uri = await BackupService.instance.exportBackup(backup);
      if (uri == null || !mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Respaldo guardado correctamente.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo crear el respaldo: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _dataOperationInProgress = false);
    }
  }

  Future<void> _restoreBackup(BuildContext context, AppState state) async {
    setState(() => _dataOperationInProgress = true);

    try {
      final backup = await BackupService.instance.pickBackup();
      if (backup == null || !mounted) return;

      final accepted = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Restaurar respaldo'),
          content: Text(
            'Se encontraron ${backup.movements.length} movimientos.\n\n'
            'Perfil: ${backup.name.isEmpty ? 'Sin nombre' : backup.name}\n'
            'Creado: ${_backupDateLabel(backup.exportedAt)}\n\n'
            'Los movimientos y preferencias actuales serán reemplazados. '
            'Esta acción no se puede deshacer desde MotoCaja.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Restaurar'),
            ),
          ],
        ),
      );

      if (accepted != true || !mounted) return;

      await state.restoreBackup(backup);
      await YapeNotificationService.instance.setDetectionEnabled(
        backup.yapeDetectionEnabled,
      );
      await _refreshYapeStatus();

      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'Respaldo restaurado: ${backup.movements.length} movimientos.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
    } on FormatException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo restaurar el respaldo: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _dataOperationInProgress = false);
    }
  }

  Future<void> _showDeveloperStatus(
    BuildContext context,
    AppState state,
  ) async {
    final notifications = await NotificationService.instance
        .areNotificationsEnabled();
    final yapeAccess = await YapeNotificationService.instance
        .isNotificationAccessGranted();

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Estado técnico'),
        content: SelectableText(
          'Movimientos: ${state.movements.length}\n'
          'SQLite schema: ${AppDatabase.schemaVersion}\n'
          'Backup schema: ${BackupData.currentVersion}\n'
          'Notificaciones: ${notifications ? 'OK' : 'Sin permiso'}\n'
          'Acceso pagos: ${yapeAccess ? 'OK' : 'Sin permiso'}\n'
          'Onboarding: ${state.onboardingCompleted ? 'Completo' : 'Pendiente'}',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Future<void> _resetOnboardingForDebug(
    BuildContext context,
    AppState state,
  ) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Repetir onboarding'),
        content: const Text(
          'Esto no borra movimientos ni preferencias. Solo vuelve a mostrar el flujo inicial para pruebas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Repetir'),
          ),
        ],
      ),
    );

    if (accepted == true) {
      await state.resetOnboardingForDebug();
    }
  }

  String _backupDateLabel(DateTime date) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(date.day)}/${two(date.month)}/${date.year} '
        '${two(date.hour)}:${two(date.minute)}';
  }

  Future<void> _testNotifications(BuildContext context) async {
    final granted = await NotificationService.instance.requestPermission();
    if (!context.mounted) return;

    if (!granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'MotoCaja necesita permiso para mostrar notificaciones.',
          ),
        ),
      );
      return;
    }

    await NotificationService.instance.showTestNotification();

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Notificación de prueba enviada.')),
    );
  }

  Future<void> _changeInactivityReminder(
    BuildContext context,
    AppState state,
    bool value,
  ) async {
    if (value) {
      final granted = await NotificationService.instance.requestPermission();
      if (!granted) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Activa las notificaciones para usar recordatorios.'),
          ),
        );
        return;
      }
    }

    await state.setReminderIncome(value);
  }

  Future<void> _changeCloseReminder(
    BuildContext context,
    AppState state,
    bool value,
  ) async {
    if (value) {
      final granted = await NotificationService.instance.requestPermission();
      if (!granted) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Activa las notificaciones para usar recordatorios.'),
          ),
        );
        return;
      }
    }

    await state.setReminderClose(value);
  }

  Future<void> _changeYapeDetection(BuildContext context, bool value) async {
    if (value) {
      final accepted = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Detectar pagos de Yape y Plin'),
          content: const Text(
            'Para sugerirte el registro de pagos, Android debe permitir que '
            'MotoCaja observe las notificaciones de Yape y las notificaciones '
            'de Plin de bancos compatibles. El análisis se hace localmente en '
            'este teléfono y el ingreso no se guarda hasta que tú pulses '
            'Registrar.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Continuar'),
            ),
          ],
        ),
      );

      if (accepted != true) return;

      final notificationsGranted = await NotificationService.instance
          .requestPermission();
      if (!notificationsGranted) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'MotoCaja también necesita permiso para mostrarte la sugerencia de registro.',
            ),
          ),
        );
        return;
      }
    }

    await YapeNotificationService.instance.setDetectionEnabled(value);
    await _refreshYapeStatus();

    if (value && !_yapeAccessGranted) {
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Falta un permiso de Android'),
          content: const Text(
            'En la siguiente pantalla activa el acceso para '
            '“MotoCaja - Detector de pagos” y vuelve a la aplicación.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Abrir ajustes'),
            ),
          ],
        ),
      );
      await _openYapeAccessSettings();
    }
  }

  Future<void> _openYapeAccessSettings() async {
    await YapeNotificationService.instance.openNotificationAccessSettings();
  }

  Future<void> _startRawPaymentCapture() async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Captura temporal de Plin'),
        content: const Text(
          'Durante 2 minutos MotoCaja guardará localmente el título y texto de '
          'las notificaciones que aparezcan, sin importar qué app las envíe. '
          'Esto sirve para descubrir el origen real del aviso de Plin.\n\n'
          'La captura se detiene sola y no envía datos a ningún servidor. Para '
          'cuidar tu privacidad, haz la prueba cuando no esperes mensajes privados.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Iniciar 2 min'),
          ),
        ],
      ),
    );

    if (accepted != true || !mounted) return;

    try {
      await YapeNotificationService.instance.startRawDiagnosticCapture();
      if (!mounted) return;
      setState(() => _lastYapeDiagnostic = null);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Captura activa por 2 minutos. Ahora recibe un Plin y luego abre Diagnóstico de pagos.',
            ),
            duration: Duration(seconds: 8),
          ),
        );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo iniciar la captura: $error')),
      );
    }
  }

  Future<void> _showLastYapeDiagnostic() async {
    await _refreshYapeStatus();
    if (!mounted) return;

    List<PaymentDiagnosticEvent> history = const [];
    try {
      history = await YapeNotificationService.instance.getDiagnosticHistory();
    } catch (_) {
      // Compatibilidad con una instalación nativa anterior.
    }

    if (!mounted) return;

    if (history.isEmpty) {
      final diagnostic = _lastYapeDiagnostic;
      if (diagnostic == null || diagnostic.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Aún no hemos detectado una notificación de Yape o de una entidad Plin. '
              'Realiza una prueba y vuelve a abrir este diagnóstico.',
            ),
          ),
        );
        return;
      }

      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Diagnóstico de pagos'),
          content: SingleChildScrollView(
            child: SelectableText(
              'Fuente: ${diagnostic.sourceName}\n'
              'Paquete: ${diagnostic.packageName}\n\n'
              'Título:\n${diagnostic.title}\n\n'
              'Texto:\n${diagnostic.text}\n\n'
              'Detalles:\n${diagnostic.bigText}',
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
      return;
    }

    String timeLabel(DateTime? value) {
      if (value == null) return '-';
      String two(int n) => n.toString().padLeft(2, '0');
      return '${two(value.day)}/${two(value.month)}/${value.year} '
          '${two(value.hour)}:${two(value.minute)}:${two(value.second)}';
    }

    final buffer = StringBuffer();
    for (var index = 0; index < history.length; index++) {
      final event = history[index];
      if (index > 0) {
        buffer.writeln('\n${List.filled(34, '─').join()}\n');
      }
      buffer.writeln('#${index + 1} · ${timeLabel(event.capturedAt)}');
      buffer.writeln('Decisión: ${event.decision}');
      buffer.writeln('Fuente: ${event.sourceName}');
      if (event.appLabel.isNotEmpty) {
        buffer.writeln('App: ${event.appLabel}');
      }
      buffer.writeln('Paquete: ${event.packageName}');
      if (event.channelId.isNotEmpty) {
        buffer.writeln('Canal: ${event.channelId}');
      }
      if (event.tag.isNotEmpty) buffer.writeln('Tag: ${event.tag}');
      if (event.amount != null) {
        buffer.writeln('Monto interpretado: S/ ${event.amount!.toStringAsFixed(2)}');
      }
      buffer.writeln('Título: ${event.title.isEmpty ? '(vacío)' : event.title}');
      buffer.writeln('Texto: ${event.text.isEmpty ? '(vacío)' : event.text}');
      if (event.details.isNotEmpty) {
        buffer.writeln('Detalles:\n${event.details}');
      }
      if (event.postedAt != null && event.postedAt != event.capturedAt) {
        buffer.writeln('Android postTime: ${timeLabel(event.postedAt)}');
      }
      if (event.notificationWhen != null) {
        buffer.writeln('Notification when: ${timeLabel(event.notificationWhen)}');
      }
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Historial de diagnóstico'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: SelectableText(buffer.toString()),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await YapeNotificationService.instance.clearDiagnosticHistory();
              if (dialogContext.mounted) Navigator.pop(dialogContext);
              await _refreshYapeStatus();
            },
            child: const Text('Limpiar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickCloseTime(BuildContext context, AppState state) async {
    final selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: state.closeHour, minute: state.closeMinute),
      helpText: 'Hora para cerrar tu jornada',
    );

    if (selected == null) return;
    await state.setCloseTime(hour: selected.hour, minute: selected.minute);
  }

  void _intervalSheet(BuildContext context, AppState state) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text(
                'Recordarme después de',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            for (final minutes in const [60, 90, 120])
              RadioListTile<int>(
                value: minutes,
                groupValue: state.reminderIntervalMinutes,
                title: Text(_intervalLabel(minutes)),
                onChanged: (value) async {
                  if (value == null) return;
                  await state.setReminderIntervalMinutes(value);
                  if (sheetContext.mounted) Navigator.pop(sheetContext);
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _frequentRatesDialog(
    BuildContext context,
    AppState state,
  ) async {
    final rates = await showDialog<List<double>>(
      context: context,
      builder: (_) => _FrequentRatesDialog(initialRates: state.frequentRates),
    );

    if (rates == null || !mounted) return;

    // El Future de showDialog puede resolverse antes de que termine
    // por completo la animación de salida de la ruta. Dejamos que el
    // overlay termine su desmontaje antes de notificar a Provider.
    await Future<void>.delayed(const Duration(milliseconds: 220));

    if (!mounted) return;

    try {
      await context.read<AppState>().setFrequentRates(rates);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('No se pudieron guardar las tarifas: $error'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Tarifas frecuentes actualizadas.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  String _ratesSubtitle(List<double> rates) =>
      rates.map((value) => 'S/ ${_rateValue(value)}').join(', ');

  String _rateValue(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value
            .toStringAsFixed(2)
            .replaceFirst(RegExp(r'0+$'), '')
            .replaceFirst(RegExp(r'\.$'), '');

  void _paymentSheet(BuildContext context, AppState state) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: ['Efectivo', 'Yape', 'Plin', 'Transferencia']
              .map(
                (payment) => RadioListTile<String>(
                  value: payment,
                  groupValue: state.defaultPayment,
                  title: Text(payment),
                  onChanged: (value) async {
                    if (value == null) return;
                    await state.updateProfile(newDefaultPayment: value);
                    if (sheetContext.mounted) Navigator.pop(sheetContext);
                  },
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  String _intervalLabel(int minutes) {
    if (minutes == 60) return '1 hora';
    if (minutes == 120) return '2 horas';
    return '$minutes minutos';
  }

  String _formatTime(BuildContext context, int hour, int minute) {
    return TimeOfDay(hour: hour, minute: minute).format(context);
  }
}

class _TextSettingDialog extends StatefulWidget {
  final String title;
  final String initialValue;

  const _TextSettingDialog({required this.title, required this.initialValue});

  @override
  State<_TextSettingDialog> createState() => _TextSettingDialogState();
}

class _TextSettingDialogState extends State<_TextSettingDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Guardar')),
      ],
    );
  }

  void _submit() {
    Navigator.pop(context, _controller.text.trim());
  }
}

class _FrequentRatesDialog extends StatefulWidget {
  final List<double> initialRates;

  const _FrequentRatesDialog({required this.initialRates});

  @override
  State<_FrequentRatesDialog> createState() => _FrequentRatesDialogState();
}

class _FrequentRatesDialogState extends State<_FrequentRatesDialog> {
  late final List<TextEditingController> _controllers;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      4,
      (index) => TextEditingController(
        text: index < widget.initialRates.length
            ? _rateValue(widget.initialRates[index])
            : '',
      ),
    );
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Tarifas frecuentes'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Configura los 4 montos que usas con mayor frecuencia. '
              'Se mostrarán como accesos rápidos al registrar un servicio.',
              style: TextStyle(fontSize: 12, color: AppColors.muted),
            ),
            const SizedBox(height: 14),
            for (var i = 0; i < _controllers.length; i++) ...[
              TextField(
                controller: _controllers[i],
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textInputAction: i == _controllers.length - 1
                    ? TextInputAction.done
                    : TextInputAction.next,
                onChanged: (_) {
                  if (_errorText != null) {
                    setState(() => _errorText = null);
                  }
                },
                onSubmitted: i == _controllers.length - 1
                    ? (_) => _submit()
                    : null,
                decoration: InputDecoration(
                  labelText: 'Tarifa ${i + 1}',
                  prefixText: 'S/ ',
                ),
              ),
              if (i < _controllers.length - 1) const SizedBox(height: 10),
            ],
            if (_errorText != null) ...[
              const SizedBox(height: 10),
              Text(
                _errorText!,
                style: const TextStyle(
                  color: AppColors.red,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Guardar')),
      ],
    );
  }

  void _submit() {
    final values = _controllers
        .map(
          (controller) =>
              double.tryParse(controller.text.trim().replaceAll(',', '.')),
        )
        .toList();

    if (values.any((value) => value == null || value <= 0)) {
      setState(() {
        _errorText = 'Ingresa 4 tarifas mayores a cero.';
      });
      return;
    }

    final rates = values.cast<double>();

    if (rates.toSet().length != rates.length) {
      setState(() {
        _errorText = 'Las tarifas frecuentes no deben repetirse.';
      });
      return;
    }

    Navigator.pop(context, rates);
  }

  String _rateValue(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value
            .toStringAsFixed(2)
            .replaceFirst(RegExp(r'0+$'), '')
            .replaceFirst(RegExp(r'\.$'), '');
}

class _Header extends StatelessWidget {
  final String text;

  const _Header(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Text(
      text,
      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
    ),
  );
}

class _SettingTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  const _SettingTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(9),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.navy, size: 21),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.muted,
                    ),
                  ),
              ],
            ),
          ),
          if (onTap != null)
            const Icon(Icons.chevron_right, color: AppColors.muted, size: 19),
        ],
      ),
    ),
  );
}

class _SwitchTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: AppColors.border),
      borderRadius: BorderRadius.circular(9),
    ),
    child: SwitchListTile(
      value: value,
      onChanged: onChanged,
      secondary: Icon(icon, color: AppColors.navy, size: 20),
      title: Text(
        title,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      activeThumbColor: AppColors.green,
    ),
  );
}

class _InfoCard extends StatelessWidget {
  final String text;

  const _InfoCard({required this.text});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.greenSoft,
      borderRadius: BorderRadius.circular(9),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.info_outline, size: 18, color: AppColors.green),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 10.5,
              height: 1.4,
              color: AppColors.navy,
            ),
          ),
        ),
      ],
    ),
  );
}

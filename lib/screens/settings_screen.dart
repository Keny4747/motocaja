import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/app_state.dart';
import '../services/notification_service.dart';
import '../services/yape_notification_service.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with WidgetsBindingObserver {
  bool _yapeDetectionEnabled = false;
  bool _yapeAccessGranted = false;
  YapeDiagnostic? _lastYapeDiagnostic;

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
      final enabled =
          await YapeNotificationService.instance.getDetectionEnabled();
      final access = await YapeNotificationService.instance
          .isNotificationAccessGranted();
      final diagnostic =
          await YapeNotificationService.instance.getLastDiagnostic();
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

  Future<String?> _ask(
    BuildContext context,
    String title,
    String current,
  ) async {
    final controller = TextEditingController(text: current);

    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              context,
              controller.text.trim(),
            ),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    controller.dispose();
    return result;
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
          const _SettingTile(
            icon: Icons.percent,
            title: 'Tarifas frecuentes',
            subtitle: 'S/ 5, S/ 7, S/ 8, S/ 10',
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
            title: 'Probar notificaciones',
            subtitle: 'Solicitar permiso y enviar un aviso de prueba',
            onTap: () => _testNotifications(context),
          ),
          const SizedBox(height: 8),
          _SwitchTile(
            icon: Icons.timer_outlined,
            title: 'Recordarme si dejo de registrar',
            value: state.remindIncome,
            onChanged: (value) => _changeInactivityReminder(
              context,
              state,
              value,
            ),
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
            onChanged: (value) => _changeCloseReminder(
              context,
              state,
              value,
            ),
          ),
          const SizedBox(height: 8),
          _SettingTile(
            icon: Icons.alarm_outlined,
            title: 'Hora de cierre',
            subtitle: _formatTime(
              context,
              state.closeHour,
              state.closeMinute,
            ),
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
            title: 'Detectar pagos recibidos por Yape',
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
          _SettingTile(
            icon: Icons.bug_report_outlined,
            title: 'Última notificación Yape detectada',
            subtitle: _lastYapeDiagnostic == null || _lastYapeDiagnostic!.isEmpty
                ? 'Aún no hay una notificación para analizar'
                : 'Toca para revisar el formato recibido',
            onTap: _showLastYapeDiagnostic,
          ),
          const SizedBox(height: 8),
          const _InfoCard(
            text:
                'MotoCaja solo observa notificaciones de Yape cuando activas '
                'esta función. El contenido se procesa en el teléfono; no se '
                'envía a ningún servidor. Antes de guardar un ingreso siempre '
                'te pediremos confirmación.',
          ),
          const SizedBox(height: 16),
          const _Header('Datos'),
          const _SettingTile(
            icon: Icons.download_outlined,
            title: 'Exportar información',
          ),
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
      const SnackBar(
        content: Text('Notificación de prueba enviada.'),
      ),
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


  Future<void> _changeYapeDetection(
    BuildContext context,
    bool value,
  ) async {
    if (value) {
      final accepted = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Detectar pagos de Yape'),
          content: const Text(
            'Para sugerirte el registro de pagos, Android debe permitir que '
            'MotoCaja observe las notificaciones de Yape. El análisis se hace '
            'localmente en este teléfono y el ingreso no se guarda hasta que '
            'tú pulses Registrar.',
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

      final notificationsGranted =
          await NotificationService.instance.requestPermission();
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

  Future<void> _showLastYapeDiagnostic() async {
    await _refreshYapeStatus();
    if (!mounted) return;

    final diagnostic = _lastYapeDiagnostic;
    if (diagnostic == null || diagnostic.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Aún no hemos detectado una notificación de Yape. '
            'Activa la detección y realiza un Yape de prueba.',
          ),
        ),
      );
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Diagnóstico de Yape'),
        content: SingleChildScrollView(
          child: SelectableText(
            'Título:\n${diagnostic.title}\n\n'
            'Texto:\n${diagnostic.text}\n\n'
            'Texto ampliado:\n${diagnostic.bigText}',
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
  }

  Future<void> _pickCloseTime(
    BuildContext context,
    AppState state,
  ) async {
    final selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: state.closeHour,
        minute: state.closeMinute,
      ),
      helpText: 'Hora para cerrar tu jornada',
    );

    if (selected == null) return;
    await state.setCloseTime(
      hour: selected.hour,
      minute: selected.minute,
    );
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

  String _formatTime(
    BuildContext context,
    int hour,
    int minute,
  ) {
    return TimeOfDay(hour: hour, minute: minute).format(context);
  }
}

class _Header extends StatelessWidget {
  final String text;

  const _Header(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: Text(
          text,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
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
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 11,
          ),
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
                const Icon(
                  Icons.chevron_right,
                  color: AppColors.muted,
                  size: 19,
                ),
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
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
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
            const Icon(
              Icons.info_outline,
              size: 18,
              color: AppColors.green,
            ),
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

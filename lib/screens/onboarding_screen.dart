import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/app_state.dart';
import '../services/backup_service.dart';
import '../services/notification_service.dart';
import '../services/yape_notification_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  final _nameController = TextEditingController();
  final _vehicleController = TextEditingController();
  final _rateControllers = [5, 7, 8, 10]
      .map((value) => TextEditingController(text: value.toString()))
      .toList();

  int _step = 0;
  String _payment = 'Efectivo';
  bool _enableReminders = true;
  bool _saving = false;

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _vehicleController.dispose();
    for (final controller in _rateControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _goTo(int step) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _step = step);
    _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  void _nextFromProfile() {
    if (_nameController.text.trim().isEmpty) {
      _showMessage('Ingresa tu nombre para continuar.');
      return;
    }
    if (_vehicleController.text.trim().isEmpty) {
      _showMessage('Ingresa los datos de tu moto para continuar.');
      return;
    }
    _goTo(2);
  }

  Future<void> _restoreBackup() async {
    if (_saving) return;

    setState(() => _saving = true);
    try {
      final backup = await BackupService.instance.pickBackup();
      if (backup == null || !mounted) return;

      final accepted = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Restaurar MotoCaja'),
          content: Text(
            'Este respaldo contiene ${backup.movements.length} movimientos '
            'y el perfil ${backup.name.isEmpty ? 'sin nombre' : backup.name}.\n\n'
            'Al continuar se reemplazarán los datos locales actuales.',
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

      await context.read<AppState>().restoreBackup(backup);
      await YapeNotificationService.instance.setDetectionEnabled(
        backup.yapeDetectionEnabled,
      );
    } on FormatException catch (error) {
      if (!mounted) return;
      _showMessage(error.message);
    } catch (error) {
      if (!mounted) return;
      _showMessage('No se pudo restaurar el respaldo: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _finish() async {
    if (_saving) return;

    final rates = _rateControllers
        .map(
          (controller) => double.tryParse(
            controller.text.trim().replaceAll(',', '.'),
          ),
        )
        .toList();

    if (rates.any((value) => value == null || value <= 0)) {
      _showMessage('Revisa tus tarifas frecuentes. Todas deben ser mayores a 0.');
      return;
    }

    final cleanRates = rates.whereType<double>().toSet().toList()..sort();
    if (cleanRates.length != rates.length) {
      _showMessage('Las tarifas frecuentes no deben repetirse.');
      return;
    }

    setState(() => _saving = true);

    try {
      var remindersEnabled = false;
      if (_enableReminders) {
        remindersEnabled = await NotificationService.instance.requestPermission();
      }

      if (!mounted) return;
      await context.read<AppState>().completeOnboarding(
        profileName: _nameController.text,
        profileVehicle: _vehicleController.text,
        rates: cleanRates,
        paymentMethod: _payment,
        enableReminders: remindersEnabled,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showMessage('No pudimos terminar la configuración: $error');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
              child: Row(
                children: [
                  if (_step > 0)
                    IconButton(
                      onPressed: _saving ? null : () => _goTo(_step - 1),
                      icon: const Icon(Icons.arrow_back_rounded),
                    )
                  else
                    const SizedBox(width: 48),
                  const Spacer(),
                  _StepIndicator(current: _step, total: 3),
                  const Spacer(),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _WelcomeStep(
                    onContinue: () => _goTo(1),
                    onRestore: _restoreBackup,
                    busy: _saving,
                  ),
                  _ProfileStep(
                    nameController: _nameController,
                    vehicleController: _vehicleController,
                    onContinue: _nextFromProfile,
                  ),
                  _PreferencesStep(
                    rateControllers: _rateControllers,
                    payment: _payment,
                    enableReminders: _enableReminders,
                    saving: _saving,
                    onPaymentChanged: (value) => setState(() => _payment = value),
                    onReminderChanged: (value) =>
                        setState(() => _enableReminders = value),
                    onFinish: _finish,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepIndicator extends StatelessWidget {
  final int current;
  final int total;

  const _StepIndicator({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        total,
        (index) => AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          width: index == current ? 24 : 8,
          height: 8,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            color: index == current ? AppColors.green : AppColors.border,
            borderRadius: BorderRadius.circular(99),
          ),
        ),
      ),
    );
  }
}

class _WelcomeStep extends StatelessWidget {
  final VoidCallback onContinue;
  final VoidCallback onRestore;
  final bool busy;

  const _WelcomeStep({
    required this.onContinue,
    required this.onRestore,
    required this.busy,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 30, 28, 28),
      child: Column(
        children: [
          const Spacer(),
          Container(
            width: 130,
            height: 130,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: AppColors.navy.withValues(alpha: 0.12),
                  blurRadius: 28,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Image.asset('assets/icons/motocaja.png', fit: BoxFit.cover),
            ),
          ),
          const SizedBox(height: 28),
          const Text(
            'Tu jornada, más clara.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.navy,
              fontSize: 28,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.7,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Registra servicios y gastos en segundos. MotoCaja calcula lo que realmente ganaste y mantiene todo en tu teléfono.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.muted,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 26),
          const _FeatureLine(
            icon: Icons.flash_on_rounded,
            text: 'Registro rápido durante la jornada',
          ),
          const SizedBox(height: 10),
          const _FeatureLine(
            icon: Icons.lock_outline_rounded,
            text: 'Tus movimientos se guardan localmente',
          ),
          const SizedBox(height: 10),
          const _FeatureLine(
            icon: Icons.insights_rounded,
            text: 'Resumen diario, semanal y mensual',
          ),
          const Spacer(),
          PrimaryButton(
            label: 'Comenzar',
            loading: busy,
            onPressed: busy ? null : onContinue,
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton.icon(
              onPressed: busy ? null : onRestore,
              icon: const Icon(Icons.settings_backup_restore_rounded),
              label: const Text('Restaurar un respaldo'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileStep extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController vehicleController;
  final VoidCallback onContinue;

  const _ProfileStep({
    required this.nameController,
    required this.vehicleController,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 34, 24, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Primero, hagámoslo tuyo',
            style: TextStyle(
              color: AppColors.navy,
              fontSize: 26,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Estos datos solo se usan para personalizar MotoCaja y puedes cambiarlos después.',
            style: TextStyle(color: AppColors.muted, height: 1.45),
          ),
          const SizedBox(height: 30),
          const SectionLabel('Tu nombre'),
          TextField(
            controller: nameController,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              hintText: 'Ej. Keny',
              prefixIcon: Icon(Icons.person_outline_rounded),
            ),
          ),
          const SizedBox(height: 20),
          const SectionLabel('Tu moto'),
          TextField(
            controller: vehicleController,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => onContinue(),
            decoration: const InputDecoration(
              hintText: 'Ej. Honda Wave',
              prefixIcon: Icon(Icons.two_wheeler_rounded),
            ),
          ),
          const SizedBox(height: 34),
          PrimaryButton(label: 'Continuar', onPressed: onContinue),
        ],
      ),
    );
  }
}

class _PreferencesStep extends StatelessWidget {
  final List<TextEditingController> rateControllers;
  final String payment;
  final bool enableReminders;
  final bool saving;
  final ValueChanged<String> onPaymentChanged;
  final ValueChanged<bool> onReminderChanged;
  final VoidCallback onFinish;

  const _PreferencesStep({
    required this.rateControllers,
    required this.payment,
    required this.enableReminders,
    required this.saving,
    required this.onPaymentChanged,
    required this.onReminderChanged,
    required this.onFinish,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Configura tus atajos',
            style: TextStyle(
              color: AppColors.navy,
              fontSize: 26,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Estas tarifas aparecerán como botones rápidos al registrar un servicio.',
            style: TextStyle(color: AppColors.muted, height: 1.45),
          ),
          const SizedBox(height: 24),
          const SectionLabel('Tarifas frecuentes'),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 2.45,
            ),
            itemCount: rateControllers.length,
            itemBuilder: (_, index) => TextField(
              controller: rateControllers[index],
              enabled: !saving,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                prefixText: 'S/ ',
                labelText: 'Tarifa ${index + 1}',
              ),
            ),
          ),
          const SizedBox(height: 24),
          const SectionLabel('Pago predeterminado'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ['Efectivo', 'Yape', 'Plin', 'Transferencia']
                .map(
                  (item) => ChoiceChip(
                    label: Text(item),
                    selected: payment == item,
                    onSelected: saving ? null : (_) => onPaymentChanged(item),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 24),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: SwitchListTile(
              value: enableReminders,
              onChanged: saving ? null : onReminderChanged,
              secondary: const Icon(
                Icons.notifications_active_outlined,
                color: AppColors.green,
              ),
              title: const Text(
                'Activar recordatorios',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: const Text(
                'MotoCaja podrá recordarte registrar movimientos y cerrar tu jornada. Puedes cambiarlo después.',
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'La detección inteligente de Yape y Plin se activa por separado desde Configuración porque Android requiere un permiso especial.',
            style: TextStyle(color: AppColors.muted, fontSize: 11, height: 1.4),
          ),
          const SizedBox(height: 30),
          PrimaryButton(
            label: 'Entrar a MotoCaja',
            loading: saving,
            onPressed: saving ? null : onFinish,
          ),
        ],
      ),
    );
  }
}

class _FeatureLine extends StatelessWidget {
  final IconData icon;
  final String text;

  const _FeatureLine({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: const BoxDecoration(
            color: AppColors.greenSoft,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppColors.green, size: 19),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: AppColors.navy,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

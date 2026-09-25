import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/app_state.dart';
import '../services/notification_service.dart';
import '../services/yape_notification_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_feedback.dart';
import '../widgets/common.dart';
import 'home_screen.dart';
import 'movements_screen.dart';
import 'register_service_screen.dart';
import 'settings_screen.dart';
import 'summary_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  int index = 0;
  bool _processingDetectedPayment = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    NotificationService.instance.navigationPayload.addListener(
      _onNotificationPayloadChanged,
    );

    YapeNotificationService.instance.initialize();
    YapeNotificationService.instance.pendingPaymentSignal.addListener(
      _onPendingPaymentSignal,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _consumeNavigationPayload();
      await _consumePendingPayment();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    NotificationService.instance.navigationPayload.removeListener(
      _onNotificationPayloadChanged,
    );
    YapeNotificationService.instance.pendingPaymentSignal.removeListener(
      _onPendingPaymentSignal,
    );
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _consumePendingPayment();
    }
  }

  void _onNotificationPayloadChanged() {
    if (!mounted) return;
    _consumeNavigationPayload();
  }

  void _consumeNavigationPayload() {
    final payload = NotificationService.instance.consumePendingPayload();
    if (payload == null || !mounted) return;

    switch (payload) {
      case 'daily_summary':
        setState(() => index = 2);
        break;
      case 'register_service':
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const RegisterServiceScreen(),
          ),
        );
        break;
    }
  }

  void _onPendingPaymentSignal() {
    _consumePendingPayment();
  }

  Future<void> _consumePendingPayment() async {
    if (_processingDetectedPayment || !mounted) return;
    _processingDetectedPayment = true;

    try {
      final payment =
          await YapeNotificationService.instance.consumePendingPayment();
      if (payment == null || !mounted) return;

      final registered = await context.read<AppState>().addDetectedPaymentIncome(
            amount: payment.amount,
            eventId: payment.eventId,
            detectedAt: payment.detectedAt,
            paymentMethod: payment.paymentMethod,
          );

      if (!registered || !mounted) return;

      await showActionSuccessDialog(
        context,
        title: '${payment.paymentMethod} registrado',
        message: '${money(payment.amount)} · ${payment.paymentMethod}',
        icon: Icons.account_balance_wallet_rounded,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo registrar el pago detectado: $error'),
        ),
      );
    } finally {
      _processingDetectedPayment = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(onSeeAll: () => setState(() => index = 1)),
      const MovementsScreen(),
      const SummaryScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: index, children: pages),
      bottomNavigationBar: NavigationBar(
        height: 66,
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() => index = i),
        indicatorColor: Colors.transparent,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home, color: AppColors.green),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_today_outlined),
            selectedIcon: Icon(Icons.calendar_today, color: AppColors.green),
            label: 'Movimientos',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart, color: AppColors.green),
            label: 'Resumen',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings, color: AppColors.green),
            label: 'Configuración',
          ),
        ],
      ),
    );
  }
}

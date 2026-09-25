import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/movement_tile.dart';
import 'movement_detail_screen.dart';
import 'register_expense_screen.dart';
import 'register_service_screen.dart';

class HomeScreen extends StatelessWidget {
  final VoidCallback onSeeAll;

  const HomeScreen({
    super.key,
    required this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final today = state.forToday();
    final income = state.incomeOf(today);
    final expenses = state.expensesOf(today);
    final services = state.servicesOf(today);
    final firstName = state.name.trim().split(' ').first;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        children: [
          Row(
            children: [
              const Icon(
                Icons.two_wheeler,
                color: AppColors.green,
                size: 30,
              ),
              const SizedBox(width: 7),
              const Text(
                'MotoCaja',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: AppColors.navy,
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Avisos',
                onPressed: () => _showAlerts(context, state),
                icon: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(Icons.notifications_none, size: 27),
                    if (state.hasUnreadAlerts)
                      Positioned(
                        right: -1,
                        top: -1,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Hola, $firstName 👋',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 20,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            shortDate(DateTime.now()),
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: const LinearGradient(
                colors: [AppColors.greenDark, AppColors.green],
              ),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 13),
                  child: Column(
                    children: [
                      const Text(
                        'GANANCIA DE HOY',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        money(income - expenses),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 31,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 11,
                    horizontal: 14,
                  ),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF7FBF8),
                    borderRadius: BorderRadius.vertical(
                      bottom: Radius.circular(12),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _MiniStat(
                          icon: Icons.arrow_upward,
                          value: money(income),
                          label: 'Ingresos',
                          positive: true,
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 37,
                        color: AppColors.border,
                      ),
                      Expanded(
                        child: _MiniStat(
                          icon: Icons.arrow_downward,
                          value: money(expenses),
                          label: 'Gastos',
                          positive: false,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.green,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const RegisterServiceScreen(),
                ),
              ),
              icon: const Icon(Icons.add, size: 28),
              label: const Row(
                children: [
                  SizedBox(width: 8),
                  Text(
                    'Registrar servicio',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  Spacer(),
                  Icon(Icons.chevron_right),
                ],
              ),
            ),
          ),
          const SizedBox(height: 9),
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.redSoft,
                foregroundColor: AppColors.red,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const RegisterExpenseScreen(),
                ),
              ),
              icon: const Icon(Icons.remove_circle, size: 26),
              label: const Row(
                children: [
                  SizedBox(width: 8),
                  Text(
                    'Registrar gasto',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  Spacer(),
                  Icon(Icons.chevron_right),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          InkWell(
            onTap: onSeeAll,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 11,
              ),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.bar_chart,
                    color: AppColors.green,
                    size: 30,
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Servicios realizados hoy',
                        style: TextStyle(
                          color: AppColors.muted,
                          fontSize: 11,
                        ),
                      ),
                      Text(
                        '$services',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 22,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.chevron_right,
                    color: AppColors.muted,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Text(
                'Últimos movimientos',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppColors.navy,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: onSeeAll,
                child: const Text('Ver todos'),
              ),
            ],
          ),
          if (today.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'Aún no hay movimientos hoy.',
                  style: TextStyle(color: AppColors.muted),
                ),
              ),
            )
          else
            ...today.take(4).map(
                  (movement) => MovementTile(
                    movement: movement,
                    compact: true,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MovementDetailScreen(
                          movement: movement,
                        ),
                      ),
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  Future<void> _showAlerts(BuildContext context, AppState state) async {
    await state.markAlertsViewed();
    if (!context.mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _AlertsSheet(),
    );
  }
}

class _AlertsSheet extends StatelessWidget {
  const _AlertsSheet();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final digitalPayments = state.recentDigitalPayments;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.72,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
          children: [
            const Text(
              'Centro de avisos',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: AppColors.navy,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Pagos digitales recientes y recordatorios activos.',
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Pagos digitales',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: AppColors.navy,
              ),
            ),
            const SizedBox(height: 8),
            if (digitalPayments.isEmpty)
              const _AlertInfoCard(
                icon: Icons.account_balance_wallet_outlined,
                title: 'Sin pagos digitales recientes',
                subtitle: 'Aquí aparecerán tus últimos movimientos Yape y Plin.',
              )
            else
              ...digitalPayments.map(
                (movement) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _AlertInfoCard(
                    icon: Icons.account_balance_wallet_outlined,
                    title:
                        '${movement.paymentMethod} · ${money(movement.amount)}',
                    subtitle: _movementDateLabel(movement.date),
                  ),
                ),
              ),
            const SizedBox(height: 10),
            const Text(
              'Recordatorios',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: AppColors.navy,
              ),
            ),
            const SizedBox(height: 8),
            if (!state.remindIncome && !state.remindClose)
              const _AlertInfoCard(
                icon: Icons.notifications_off_outlined,
                title: 'Recordatorios desactivados',
                subtitle: 'Puedes activarlos desde Configuración.',
              )
            else ...[
              if (state.remindIncome)
                _AlertInfoCard(
                  icon: Icons.timer_outlined,
                  title: 'Recordatorio de actividad activo',
                  subtitle:
                      'Te avisará tras ${state.reminderIntervalMinutes} minutos sin movimientos.',
                ),
              if (state.remindIncome && state.remindClose)
                const SizedBox(height: 8),
              if (state.remindClose)
                _AlertInfoCard(
                  icon: Icons.nights_stay_outlined,
                  title: 'Cierre diario activo',
                  subtitle:
                      'Programado para las ${_timeLabel(state.closeHour, state.closeMinute)}.',
                ),
            ],
          ],
        ),
      ),
    );
  }

  static String _movementDateLabel(DateTime date) {
    final now = DateTime.now();
    final isToday = date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
    final prefix = isToday
        ? 'Hoy'
        : '${date.day.toString().padLeft(2, '0')}/'
            '${date.month.toString().padLeft(2, '0')}/${date.year}';
    return '$prefix · ${_timeLabel(date.hour, date.minute)}';
  }

  static String _timeLabel(int hour, int minute) {
    final hour12 = hour % 12 == 0 ? 12 : hour % 12;
    final suffix = hour >= 12 ? 'p. m.' : 'a. m.';
    return '$hour12:${minute.toString().padLeft(2, '0')} $suffix';
  }
}

class _AlertInfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _AlertInfoCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              color: AppColors.greenSoft,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.greenDark, size: 21),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final bool positive;

  const _MiniStat({
    required this.icon,
    required this.value,
    required this.label,
    required this.positive,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: positive ? AppColors.greenSoft : AppColors.redSoft,
          ),
          child: Icon(
            icon,
            color: positive ? AppColors.green : AppColors.red,
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: positive ? AppColors.greenDark : AppColors.red,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

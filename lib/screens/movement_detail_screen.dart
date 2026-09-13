import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/movement.dart';
import '../services/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/app_feedback.dart';
import '../widgets/common.dart';
import 'edit_movement_screen.dart';

class MovementDetailScreen extends StatefulWidget {
  final Movement movement;

  const MovementDetailScreen({
    super.key,
    required this.movement,
  });

  @override
  State<MovementDetailScreen> createState() => _MovementDetailScreenState();
}

class _MovementDetailScreenState extends State<MovementDetailScreen> {
  late Movement movement;
  bool deleting = false;

  bool get isIncome => movement.type == MovementType.income;

  @override
  void initState() {
    super.initState();
    movement = widget.movement;
  }

  Future<void> _edit() async {
    final updated = await Navigator.push<Movement>(
      context,
      MaterialPageRoute(
        builder: (_) => EditMovementScreen(movement: movement),
      ),
    );

    if (updated != null && mounted) {
      setState(() => movement = updated);
    }
  }

  Future<void> _delete() async {
    if (deleting) return;

    final confirmed = await showDeleteConfirmationDialog(
      context,
      amount: money(movement.amount),
      isIncome: isIncome,
    );

    if (!confirmed || !mounted) return;

    setState(() => deleting = true);

    try {
      await context.read<AppState>().deleteMovement(movement.id);

      if (!mounted) return;
      await showActionSuccessDialog(
        context,
        title: 'Movimiento eliminado',
        message: '${money(movement.amount)} fue retirado del historial',
        icon: Icons.delete_sweep_rounded,
        accent: AppColors.red,
      );

      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() => deleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo eliminar el movimiento: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = isIncome ? AppColors.green : AppColors.red;
    final soft = isIncome ? AppColors.greenSoft : AppColors.redSoft;

    return Scaffold(
      appBar: AppBar(title: const Text('Detalle del movimiento')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 18),
              decoration: BoxDecoration(
                color: soft,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Icon(
                      isIncome ? Icons.arrow_upward : Icons.arrow_downward,
                      color: accent,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    isIncome ? 'INGRESO' : 'GASTO',
                    style: TextStyle(
                      color: accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    money(movement.amount),
                    style: const TextStyle(
                      color: AppColors.navy,
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _DetailCard(
              children: [
                _DetailRow(
                  icon: Icons.category_outlined,
                  label: 'Categoría',
                  value: movement.category,
                ),
                _DetailRow(
                  icon: Icons.account_balance_wallet_outlined,
                  label: 'Método de pago',
                  value: movement.paymentMethod,
                ),
                _DetailRow(
                  icon: Icons.calendar_today_outlined,
                  label: 'Fecha',
                  value: shortDate(movement.date),
                ),
                _DetailRow(
                  icon: Icons.schedule_outlined,
                  label: 'Hora',
                  value: hour(movement.date),
                  showDivider: false,
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: deleting ? null : _edit,
                icon: const Icon(Icons.edit_outlined),
                label: const Text(
                  'Editar movimiento',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 52,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.red,
                  side: const BorderSide(color: AppColors.red),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: deleting ? null : _delete,
                icon: const Icon(Icons.delete_outline),
                label: Text(
                  deleting ? 'Eliminando...' : 'Eliminar movimiento',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  final List<Widget> children;

  const _DetailCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(children: children),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool showDivider;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        border: showDivider
            ? const Border(bottom: BorderSide(color: AppColors.border))
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 21, color: AppColors.muted),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
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

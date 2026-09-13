import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/movement.dart';
import '../services/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/app_feedback.dart';
import '../widgets/common.dart';

class EditMovementScreen extends StatefulWidget {
  final Movement movement;

  const EditMovementScreen({
    super.key,
    required this.movement,
  });

  @override
  State<EditMovementScreen> createState() => _EditMovementScreenState();
}

class _EditMovementScreenState extends State<EditMovementScreen> {
  late final TextEditingController amountController;
  late String category;
  late String payment;
  bool saving = false;

  double get amount =>
      double.tryParse(amountController.text.replaceAll(',', '.')) ?? 0;

  bool get isIncome => widget.movement.type == MovementType.income;

  @override
  void initState() {
    super.initState();
    amountController = TextEditingController(
      text: widget.movement.amount.toStringAsFixed(2),
    );
    category = widget.movement.category;
    payment = widget.movement.paymentMethod;
  }

  @override
  void dispose() {
    amountController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (amount <= 0 || saving) return;

    setState(() => saving = true);

    final updated = widget.movement.copyWith(
      amount: amount,
      category: isIncome ? 'Servicio' : category,
      paymentMethod: payment,
    );

    try {
      await context.read<AppState>().updateMovement(updated);

      if (!mounted) return;
      FocusManager.instance.primaryFocus?.unfocus();
      await showActionSuccessDialog(
        context,
        title: 'Movimiento actualizado',
        message: '${money(updated.amount)} · ${updated.paymentMethod}',
        icon: Icons.edit_rounded,
      );

      if (mounted) Navigator.pop(context, updated);
    } catch (error) {
      if (!mounted) return;
      setState(() => saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar el cambio: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Editar movimiento')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionLabel(isIncome ? 'Monto del servicio' : 'Monto del gasto'),
              TextField(
                controller: amountController,
                enabled: !saving,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  prefixText: 'S/  ',
                  hintText: '0.00',
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 20),
              if (!isIncome) ...[
                const SectionLabel('Categoría'),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 2.7,
                  children: [
                    ('Gasolina', Icons.local_gas_station_outlined),
                    ('Mantenimiento', Icons.build_outlined),
                    ('Alimentación', Icons.restaurant_outlined),
                    ('Repuestos', Icons.settings_outlined),
                    ('Lavado', Icons.water_drop_outlined),
                    ('Otros', Icons.more_horiz),
                  ].map((item) {
                    final selected = category == item.$1;
                    return InkWell(
                      onTap: saving ? null : () => setState(() => category = item.$1),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: selected ? AppColors.redSoft : AppColors.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: selected
                                ? const Color(0xFFFFC8C8)
                                : AppColors.border,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              item.$2,
                              color: selected ? AppColors.red : AppColors.navy,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                item.$1,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
              ],
              SectionLabel(
                isIncome ? '¿Cómo te pagaron?' : '¿Cómo lo pagaste?',
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Column(
                  children: [
                    ('Efectivo', Icons.payments_outlined),
                    ('Yape', Icons.account_balance_wallet_outlined),
                    ('Plin', Icons.phone_android_outlined),
                    ('Transferencia', Icons.account_balance_outlined),
                  ]
                      .map(
                        (item) => PaymentTile(
                          label: item.$1,
                          icon: item.$2,
                          selected: payment == item.$1,
                          onTap: saving ? () {} : () => setState(() => payment = item.$1),
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: 34),
              PrimaryButton(
                danger: !isIncome,
                label: 'Guardar cambios',
                loading: saving,
                onPressed: amount > 0 && !saving ? _save : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

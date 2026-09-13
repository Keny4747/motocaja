import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/app_feedback.dart';
import '../widgets/common.dart';

class RegisterExpenseScreen extends StatefulWidget {
  const RegisterExpenseScreen({super.key});

  @override
  State<RegisterExpenseScreen> createState() => _RegisterExpenseScreenState();
}

class _RegisterExpenseScreenState extends State<RegisterExpenseScreen> {
  final amountController = TextEditingController();
  String category = 'Gasolina';
  String payment = 'Efectivo';
  bool saving = false;
  bool _defaultPaymentLoaded = false;

  double get amount =>
      double.tryParse(amountController.text.replaceAll(',', '.')) ?? 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_defaultPaymentLoaded) {
      payment = context.read<AppState>().defaultPayment;
      _defaultPaymentLoaded = true;
    }
  }

  @override
  void dispose() {
    amountController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final currentAmount = amount;
    if (currentAmount <= 0 || saving) return;

    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => saving = true);

    try {
      await context.read<AppState>().addExpense(
            currentAmount,
            category,
            payment,
          );

      if (!mounted) return;
      await showActionSuccessDialog(
        context,
        title: 'Gasto registrado',
        message: '${money(currentAmount)} · $category',
        icon: Icons.receipt_long_rounded,
      );

      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() => saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo registrar el gasto: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Registrar gasto')),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionLabel('¿Cuánto gastaste?'),
                TextField(
                  controller: amountController,
                  enabled: !saving,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    prefixText: 'S/  ',
                    hintText: '0.00',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 18),
                const SectionLabel('¿En qué gastaste?'),
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
                      onTap: saving
                          ? null
                          : () => setState(() => category = item.$1),
                      borderRadius: BorderRadius.circular(10),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.redSoft
                              : AppColors.surface,
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
                              color: selected
                                  ? AppColors.red
                                  : AppColors.navy,
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
                const SectionLabel('¿Cómo lo pagaste?'),
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
                            onTap: saving
                                ? () {}
                                : () => setState(() => payment = item.$1),
                          ),
                        )
                        .toList(),
                  ),
                ),
                const SizedBox(height: 34),
                PrimaryButton(
                  danger: true,
                  label: 'Registrar gasto',
                  loading: saving,
                  onPressed: amount > 0 && !saving ? _register : null,
                ),
              ],
            ),
          ),
        ),
      );
}

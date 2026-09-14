import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/app_feedback.dart';
import '../widgets/common.dart';

class RegisterServiceScreen extends StatefulWidget {
  const RegisterServiceScreen({super.key});

  @override
  State<RegisterServiceScreen> createState() => _RegisterServiceScreenState();
}

class _RegisterServiceScreenState extends State<RegisterServiceScreen> {
  double? selectedAmount;
  final otherController = TextEditingController();
  String payment = 'Efectivo';
  bool saving = false;
  bool _initialPreferencesLoaded = false;

  double get amount =>
      double.tryParse(otherController.text.replaceAll(',', '.')) ??
      selectedAmount ??
      0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialPreferencesLoaded) {
      final state = context.read<AppState>();
      payment = state.defaultPayment;
      final rates = state.frequentRates;
      if (rates.isNotEmpty) {
        selectedAmount = rates.contains(7) ? 7 : rates.first;
      }
      _initialPreferencesLoaded = true;
    }
  }

  @override
  void dispose() {
    otherController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final currentAmount = amount;
    if (currentAmount <= 0 || saving) return;

    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => saving = true);

    try {
      await context.read<AppState>().addIncome(currentAmount, payment);

      if (!mounted) return;
      await showActionSuccessDialog(
        context,
        title: 'Servicio registrado',
        message: '${money(currentAmount)} · $payment',
        icon: Icons.two_wheeler_rounded,
      );

      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() => saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo registrar el servicio: $error')),
      );
    }
  }

  String _rateLabel(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');

  @override
  Widget build(BuildContext context) {
    final frequentRates = context.watch<AppState>().frequentRates;

    return Scaffold(
      appBar: AppBar(title: const Text('Registrar servicio')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionLabel('¿Cuánto cobraste?'),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 2.7,
                children: frequentRates.map((value) {
                  final selected =
                      selectedAmount == value && otherController.text.isEmpty;
                  return InkWell(
                    onTap: saving
                        ? null
                        : () => setState(() {
                            selectedAmount = value;
                            otherController.clear();
                          }),
                    borderRadius: BorderRadius.circular(10),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.greenSoft
                            : AppColors.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: selected
                              ? AppColors.green
                              : AppColors.border,
                        ),
                      ),
                      child: Text(
                        'S/ ${_rateLabel(value)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              const SectionLabel('Otro monto'),
              TextField(
                controller: otherController,
                enabled: !saving,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  prefixText: 'S/  ',
                  hintText: '0.00',
                ),
                onChanged: (_) => setState(() => selectedAmount = null),
              ),
              const SizedBox(height: 22),
              const SectionLabel('¿Cómo te pagaron?'),
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
                label: 'Registrar servicio    ${money(amount)}',
                loading: saving,
                onPressed: amount > 0 && !saving ? _register : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

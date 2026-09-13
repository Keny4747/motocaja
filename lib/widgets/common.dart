import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

String money(double value) => 'S/ ${value.toStringAsFixed(2)}';

String shortDate(DateTime date) {
  const months = ['enero','febrero','marzo','abril','mayo','junio','julio','agosto','septiembre','octubre','noviembre','diciembre'];
  const days = ['Lunes','Martes','Miércoles','Jueves','Viernes','Sábado','Domingo'];
  return '${days[date.weekday - 1]}, ${date.day} de ${months[date.month - 1]} de ${date.year}';
}

String hour(DateTime date) {
  final h = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final m = date.minute.toString().padLeft(2, '0');
  return '$h:$m ${date.hour >= 12 ? 'PM' : 'AM'}';
}

class SectionLabel extends StatelessWidget {
  final String text;
  const SectionLabel(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.navy)),
  );
}

class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool danger;
  final bool loading;

  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.danger = false,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 52,
    child: FilledButton(
      onPressed: loading ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: danger ? AppColors.red : AppColors.green,
        foregroundColor: Colors.white,
        disabledBackgroundColor: danger
            ? AppColors.red.withValues(alpha: 0.72)
            : AppColors.green.withValues(alpha: 0.72),
        disabledForegroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: loading
            ? const SizedBox(
                key: ValueKey('loading'),
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: Colors.white,
                ),
              )
            : Row(
                key: const ValueKey('label'),
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(label),
                  const Spacer(),
                  const Icon(Icons.chevron_right),
                ],
              ),
      ),
    ),
  );
}

class PaymentTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const PaymentTile({super.key, required this.label, required this.icon, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: selected ? AppColors.greenSoft : Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.border), top: BorderSide(color: selected ? Colors.transparent : AppColors.border)),
      ),
      child: Row(children: [
        Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off, color: selected ? AppColors.green : AppColors.muted),
        const SizedBox(width: 12),
        Icon(icon, color: selected ? AppColors.greenDark : AppColors.navy),
        const SizedBox(width: 12),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      ]),
    ),
  );
}

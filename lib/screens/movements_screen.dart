import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/movement.dart';
import '../services/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/movement_tile.dart';
import 'movement_detail_screen.dart';

class MovementsScreen extends StatefulWidget {
  const MovementsScreen({super.key});
  @override
  State<MovementsScreen> createState() => _MovementsScreenState();
}

class _MovementsScreenState extends State<MovementsScreen> {
  int filter = 0;
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final now = DateTime.now();
    List<Movement> list;
    if (filter == 0) {
      list = state.forToday();
    } else if (filter == 1) {
      final start = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
      list = state.from(start);
    } else {
      list = state.from(DateTime(now.year, now.month, 1));
    }
    final income = state.incomeOf(list), expenses = state.expensesOf(list), services = state.servicesOf(list);
    return SafeArea(child: Column(children: [
      const Padding(padding: EdgeInsets.fromLTRB(16, 18, 16, 10), child: Text('Movimientos', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppColors.navy))),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Row(children: List.generate(3, (i) => Expanded(child: Padding(padding: EdgeInsets.only(right: i < 2 ? 8 : 0), child: ChoiceChip(label: SizedBox(width: double.infinity, child: Text(['Hoy','Semana','Mes'][i], textAlign: TextAlign.center)), selected: filter == i, selectedColor: AppColors.green, labelStyle: TextStyle(color: filter == i ? Colors.white : AppColors.navy, fontWeight: FontWeight.w600), side: BorderSide.none, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), onSelected: (_) => setState(() => filter = i))))))),
      const SizedBox(height: 14),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Row(children: [const Icon(Icons.calendar_month_outlined, size: 20), const SizedBox(width: 8), Expanded(child: Text(shortDate(now), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)))])),
      Padding(padding: const EdgeInsets.fromLTRB(16, 14, 16, 8), child: Row(children: [Text('$services servicios', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)), const Spacer(), Text(money(income - expenses), style: TextStyle(color: income - expenses >= 0 ? AppColors.green : AppColors.red, fontWeight: FontWeight.w800, fontSize: 16))])),
      Expanded(child: list.isEmpty ? const Center(child: Text('No hay movimientos en este periodo.', style: TextStyle(color: AppColors.muted))) : ListView.separated(padding: const EdgeInsets.symmetric(horizontal: 16), itemCount: list.length, separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.border), itemBuilder: (_, i) {
        final movement = list[i];
        return MovementTile(
          movement: movement,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MovementDetailScreen(movement: movement),
            ),
          ),
        );
      })),
    ]));
  }
}

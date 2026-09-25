import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
  DateTime _selectedDate = _normalize(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final list = state.forDate(_selectedDate);
    final income = state.incomeOf(list);
    final expenses = state.expensesOf(list);
    final services = state.servicesOf(list);
    final profit = income - expenses;
    final isToday = AppState.sameDay(_selectedDate, DateTime.now());

    return SafeArea(
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 18, 16, 12),
            child: Text(
              'Movimientos',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: AppColors.navy,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Día anterior',
                    onPressed: () => _changeDay(-1),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: _pickDate,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.calendar_month_outlined,
                                  size: 18,
                                  color: AppColors.navy,
                                ),
                                const SizedBox(width: 7),
                                Text(
                                  isToday ? 'Hoy' : 'Fecha seleccionada',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.navy,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              shortDate(_selectedDate),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Día siguiente',
                    onPressed: isToday ? null : () => _changeDay(1),
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(
              children: [
                Text(
                  '$services servicios',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const Spacer(),
                Text(
                  money(profit),
                  style: TextStyle(
                    color: profit >= 0 ? AppColors.green : AppColors.red,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: list.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.receipt_long_outlined,
                            size: 42,
                            color: AppColors.muted,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            isToday
                                ? 'No hay movimientos registrados hoy.'
                                : 'No hay movimientos para esta fecha.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: AppColors.muted),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const Divider(
                      height: 1,
                      color: AppColors.border,
                    ),
                    itemBuilder: (_, index) {
                      final movement = list[index];
                      return MovementTile(
                        movement: movement,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MovementDetailScreen(
                              movement: movement,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _changeDay(int days) {
    final today = _normalize(DateTime.now());
    var target = _selectedDate.add(Duration(days: days));
    if (target.isAfter(today)) target = today;

    setState(() {
      _selectedDate = _normalize(target);
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020, 1, 1),
      lastDate: now,
      helpText: 'Ver movimientos del día',
      cancelText: 'Cancelar',
      confirmText: 'Ver movimientos',
    );

    if (picked == null || !mounted) return;

    setState(() {
      _selectedDate = _normalize(picked);
    });
  }

  static DateTime _normalize(DateTime date) =>
      DateTime(date.year, date.month, date.day);
}

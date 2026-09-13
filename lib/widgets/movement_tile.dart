import 'package:flutter/material.dart';

import '../models/movement.dart';
import '../theme/app_theme.dart';
import 'common.dart';

class MovementTile extends StatelessWidget {
  final Movement movement;
  final bool compact;
  final VoidCallback? onTap;

  const MovementTile({
    super.key,
    required this.movement,
    this.compact = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final income = movement.type == MovementType.income;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: compact ? 7 : 10),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: income ? AppColors.greenSoft : AppColors.redSoft,
              ),
              child: Icon(
                income ? Icons.arrow_upward : Icons.arrow_downward,
                color: income ? AppColors.green : AppColors.red,
                size: 21,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    movement.category,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    movement.paymentMethod,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            if (!compact)
              Text(
                hour(movement.date),
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 11,
                ),
              ),
            const SizedBox(width: 10),
            Text(
              money(movement.amount),
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: income ? AppColors.navy : AppColors.red,
                fontSize: 13,
              ),
            ),
            if (!compact && onTap != null)
              const Padding(
                padding: EdgeInsets.only(left: 4),
                child: Icon(
                  Icons.chevron_right,
                  color: AppColors.muted,
                  size: 18,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';

/// Small tinted pill for a status word ("Paid", "Overdue").
final class StatusPill extends StatelessWidget {
  const StatusPill({
    required this.label,
    required this.color,
    required this.container,
    super.key,
  });

  final String label;
  final Color color;
  final Color container;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: container,
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
      ),
      child: Text(label, style: AppTextStyles.caption.copyWith(color: color)),
    );
  }
}

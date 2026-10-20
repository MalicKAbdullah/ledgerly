import 'package:core_theme/core_theme.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

/// Horizontally scrolling row of single-select [AppChip]s.
final class FilterBar<T> extends StatelessWidget {
  const FilterBar({
    required this.values,
    required this.selected,
    required this.label,
    required this.onSelected,
    this.icon,
    super.key,
  });

  final List<T> values;
  final T selected;
  final String Function(T value) label;
  final ValueChanged<T> onSelected;
  final IconData? Function(T value)? icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.gutter,
          vertical: AppSpacing.sm,
        ),
        itemCount: values.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, i) {
          final value = values[i];
          return AppChip(
            label: label(value),
            icon: icon?.call(value),
            selected: value == selected,
            onTap: () => onSelected(value),
          );
        },
      ),
    );
  }
}

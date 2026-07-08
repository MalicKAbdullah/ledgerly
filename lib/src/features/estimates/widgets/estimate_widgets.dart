import 'package:core_theme/core_theme.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:ledgerly/src/core/formats.dart';
import 'package:ledgerly/src/features/estimates/models/estimate.dart';
import 'package:ledgerly/src/features/estimates/services/estimate_math.dart';

/// Small pill showing estimate status in the suite's semantic colors:
/// draft = neutral, sent = info, accepted = success, declined = error,
/// expired (derived) = warning.
final class EstimateStatusChip extends StatelessWidget {
  const EstimateStatusChip({required this.estimate, super.key});

  final Estimate estimate;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final expired = estimate.isExpired(DateTime.now());

    final (label, color, container) = switch ((expired, estimate.status)) {
      (true, _) => (
        'Expired',
        AppColors.warning(brightness),
        brightness == Brightness.dark
            ? AppColors.warningContainerDark
            : AppColors.warningContainerLight,
      ),
      (_, EstimateStatus.draft) => (
        'Draft',
        AppColors.textTertiary(brightness),
        AppColors.surfaceAlt(brightness),
      ),
      (_, EstimateStatus.sent) => (
        'Sent',
        AppColors.info(brightness),
        brightness == Brightness.dark
            ? const Color(0xFF172554)
            : const Color(0xFFDBEAFE),
      ),
      (_, EstimateStatus.accepted) => (
        'Accepted',
        AppColors.success(brightness),
        brightness == Brightness.dark
            ? AppColors.successContainerDark
            : AppColors.successContainerLight,
      ),
      (_, EstimateStatus.declined) => (
        'Declined',
        AppColors.error(brightness),
        brightness == Brightness.dark
            ? AppColors.errorContainerDark
            : AppColors.errorContainerLight,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: container,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// List tile for one estimate: number, client, validity, total, status.
final class EstimateTile extends StatelessWidget {
  const EstimateTile({
    required this.estimate,
    required this.clientName,
    required this.onTap,
    this.trailing,
    super.key,
  });

  final Estimate estimate;
  final String clientName;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totals = EstimateMath.totals(estimate);

    return VaultCard(
      onTap: onTap,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        estimate.number,
                        style: theme.textTheme.titleSmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    EstimateStatusChip(estimate: estimate),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '$clientName · valid until '
                  '${Formats.date(estimate.validUntil)}',
                  style: theme.textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(totals.total.format(), style: AppTextStyles.number),
          ?trailing,
        ],
      ),
    );
  }
}

import 'package:core_theme/core_theme.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:ledgerly/src/core/formats.dart';
import 'package:ledgerly/src/core/widgets/amount_text.dart';
import 'package:ledgerly/src/core/widgets/status_pill.dart';
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
    final c = SuiteColors.of(context);
    final expired = estimate.isExpired(DateTime.now());

    final (label, color, container) = switch ((expired, estimate.status)) {
      (true, _) => ('Expired', c.warning, c.warningContainer),
      (_, EstimateStatus.draft) => ('Draft', c.textSecondary, c.surfaceAlt),
      (_, EstimateStatus.sent) => ('Sent', c.info, c.infoContainer),
      (_, EstimateStatus.accepted) => (
        'Accepted',
        c.positive,
        c.positiveContainer,
      ),
      (_, EstimateStatus.declined) => (
        'Declined',
        c.negative,
        c.negativeContainer,
      ),
    };

    return StatusPill(label: label, color: color, container: container);
  }
}

/// Row for one estimate: number, client, validity, total, status. Place
/// several inside a [RowGroup] with a zero-leading separator inset.
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
    final totals = EstimateMath.totals(estimate);

    return AppListRow(
      onTap: onTap,
      title: estimate.number,
      subtitle:
          '$clientName · valid until ${Formats.date(estimate.validUntil)}',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              AmountText(
                totals.total,
                style: AppTextStyles.number,
                alignment: AlignmentDirectional.centerEnd,
              ),
              const SizedBox(height: AppSpacing.xs),
              EstimateStatusChip(estimate: estimate),
            ],
          ),
          ?trailing,
        ],
      ),
    );
  }
}

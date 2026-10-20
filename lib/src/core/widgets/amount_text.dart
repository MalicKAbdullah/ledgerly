import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:ledgerly/src/core/money/money.dart';

/// Renders a [Money] value as the suite's tabular figure: currency symbol and
/// minor units set small, true minus sign, shrink-to-fit.
///
/// The amount is converted from integer minor units for display only; all
/// arithmetic stays in [Money].
final class AmountText extends StatelessWidget {
  const AmountText(
    this.money, {
    this.style,
    this.tone = MoneyTone.neutral,
    this.alignment = AlignmentDirectional.centerStart,
    super.key,
  });

  final Money money;
  final TextStyle? style;
  final MoneyTone tone;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    final digits = Currencies.decimalDigits(money.currency);
    var factor = 1;
    for (var i = 0; i < digits; i++) {
      factor *= 10;
    }
    return MoneyText(
      money.minorUnits / factor,
      currency: Currencies.symbol(money.currency),
      decimals: digits,
      style: style,
      tone: tone,
      alignment: alignment,
    );
  }
}

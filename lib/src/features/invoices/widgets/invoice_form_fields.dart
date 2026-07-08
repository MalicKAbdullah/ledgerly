import 'package:core_theme/core_theme.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:ledgerly/src/core/money/money.dart';
import 'package:ledgerly/src/features/clients/models/client.dart';
import 'package:ledgerly/src/features/invoices/models/invoice.dart';
import 'package:ledgerly/src/features/invoices/services/invoice_calculator.dart';

/// Form building blocks for the invoice editor, split out to keep the
/// screen readable.
final class ClientDropdown extends StatelessWidget {
  const ClientDropdown({
    required this.clients,
    required this.selectedId,
    required this.onChanged,
    super.key,
  });

  final List<Client> clients;
  final String? selectedId;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Client', style: AppTextStyles.label),
        const SizedBox(height: AppSpacing.sm),
        DropdownButtonFormField<String>(
          key: const Key('client-dropdown'),
          initialValue: selectedId,
          hint: Text(
            clients.isEmpty
                ? 'Add a client first (Clients tab)'
                : 'Select a client',
          ),
          items: [
            for (final client in clients)
              DropdownMenuItem(
                value: client.id,
                child: Text(
                  client.company.isEmpty
                      ? client.name
                      : '${client.name} — ${client.company}',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: clients.isEmpty ? null : onChanged,
        ),
      ],
    );
  }
}

final class DateField extends StatelessWidget {
  const DateField({
    required this.label,
    required this.value,
    required this.onTap,
    super.key,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.label),
        const SizedBox(height: AppSpacing.sm),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.borderRadius),
          child: InputDecorator(
            decoration: const InputDecoration(
              suffixIcon: Icon(Icons.calendar_today_outlined, size: 18),
            ),
            child: Text(value),
          ),
        ),
      ],
    );
  }
}

final class CurrencyDropdown extends StatelessWidget {
  const CurrencyDropdown({
    required this.value,
    required this.onChanged,
    this.enabled = true,
    super.key,
  });

  final String value;
  final bool enabled;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final options = {...Currencies.supported, value}.toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Currency', style: AppTextStyles.label),
        const SizedBox(height: AppSpacing.sm),
        DropdownButtonFormField<String>(
          initialValue: value,
          items: [
            for (final code in options)
              DropdownMenuItem(
                value: code,
                child: Text('$code (${Currencies.symbol(code)})'),
              ),
          ],
          onChanged: enabled ? (code) => onChanged(code ?? value) : null,
        ),
        if (!enabled)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(
              'Remove line items to change currency.',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
      ],
    );
  }
}

final class LineItemsSection extends StatelessWidget {
  const LineItemsSection({
    required this.items,
    required this.currency,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
    super.key,
  });

  final List<LineItem> items;
  final String currency;
  final VoidCallback onAdd;
  final ValueChanged<LineItem> onEdit;
  final ValueChanged<LineItem> onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Line items', style: theme.textTheme.titleLarge),
            TextButton.icon(
              key: const Key('add-line-item'),
              onPressed: onAdd,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add item'),
            ),
          ],
        ),
        if (items.isEmpty)
          VaultCard(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Text(
                  'No items yet. Tap "Add item" to bill your work.',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ),
          ),
        for (final item in items) ...[
          VaultCard(
            onTap: () => onEdit(item),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.description,
                        style: theme.textTheme.labelLarge,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${formatQuantityMilli(item.quantityMilli)} × '
                        '${item.unitPrice(currency).format()}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Text(
                  item.total(currency).format(),
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  onPressed: () => onDelete(item),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}

final class TaxDiscountSection extends StatelessWidget {
  const TaxDiscountSection({
    required this.taxRateController,
    required this.discountController,
    required this.discountType,
    required this.currency,
    required this.onDiscountTypeChanged,
    required this.onChanged,
    super.key,
  });

  final TextEditingController taxRateController;
  final TextEditingController discountController;
  final DiscountType discountType;
  final String currency;
  final ValueChanged<DiscountType> onDiscountTypeChanged;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: VaultTextField(
                label: 'Tax rate (%)',
                controller: taxRateController,
                hint: '7.5',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: (_) => onChanged(),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: VaultTextField(
                label: discountType == DiscountType.fixed
                    ? 'Discount ($currency)'
                    : 'Discount (%)',
                controller: discountController,
                hint: discountType == DiscountType.fixed ? '50.00' : '10',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: (_) => onChanged(),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        SegmentedButton<DiscountType>(
          segments: const [
            ButtonSegment(value: DiscountType.none, label: Text('No discount')),
            ButtonSegment(value: DiscountType.percent, label: Text('Percent')),
            ButtonSegment(value: DiscountType.fixed, label: Text('Fixed')),
          ],
          selected: {discountType},
          onSelectionChanged: (selection) =>
              onDiscountTypeChanged(selection.first),
        ),
      ],
    );
  }
}

/// Live subtotal / discount / tax / total preview at the bottom of the form.
final class TotalsPreview extends StatelessWidget {
  const TotalsPreview({required this.invoice, super.key});

  final Invoice invoice;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totals = InvoiceCalculator.calculate(invoice);

    Widget row(String label, String value, {bool bold = false}) {
      final style = bold
          ? theme.textTheme.titleLarge
          : theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            );
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: style),
            Text(value, style: style),
          ],
        ),
      );
    }

    return VaultCard(
      child: Column(
        children: [
          row('Subtotal', totals.subtotal.format()),
          if (!totals.discount.isZero)
            row('Discount', '-${totals.discount.format()}'),
          if (invoice.taxRateBp != 0)
            row(
              'Tax (${formatBasisPoints(invoice.taxRateBp)}%)',
              totals.tax.format(),
            ),
          const Divider(height: 16),
          row('Total', totals.total.format(), bold: true),
        ],
      ),
    );
  }
}

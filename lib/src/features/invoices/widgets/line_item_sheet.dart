import 'package:core_theme/core_theme.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:ledgerly/src/core/money/money.dart';
import 'package:ledgerly/src/features/invoices/models/invoice.dart';
import 'package:uuid/uuid.dart';

/// Bottom sheet for adding or editing a single line item.
/// Returns the resulting [LineItem] via the sheet's future, or null if
/// cancelled.
Future<LineItem?> showLineItemSheet(
  BuildContext context, {
  required String currency,
  LineItem? existing,
}) {
  return showModalBottomSheet<LineItem>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: _LineItemForm(currency: currency, existing: existing),
    ),
  );
}

final class _LineItemForm extends StatefulWidget {
  const _LineItemForm({required this.currency, this.existing});

  final String currency;
  final LineItem? existing;

  @override
  State<_LineItemForm> createState() => _LineItemFormState();
}

final class _LineItemFormState extends State<_LineItemForm> {
  late final TextEditingController _description;
  late final TextEditingController _quantity;
  late final TextEditingController _price;

  String? _descriptionError;
  String? _quantityError;
  String? _priceError;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _description = TextEditingController(text: existing?.description ?? '');
    _quantity = TextEditingController(
      text: existing == null
          ? '1'
          : formatQuantityMilli(existing.quantityMilli),
    );
    _price = TextEditingController(
      text: existing == null
          ? ''
          : Money(existing.unitPriceMinor, widget.currency).toDecimalString(),
    );
  }

  @override
  void dispose() {
    _description.dispose();
    _quantity.dispose();
    _price.dispose();
    super.dispose();
  }

  void _submit() {
    final description = _description.text.trim();
    final quantityMilli = tryParseQuantityMilli(_quantity.text);
    Money? price;
    try {
      price = Money.parse(_price.text, widget.currency);
    } on FormatException {
      price = null;
    }

    setState(() {
      _descriptionError = description.isEmpty
          ? 'Description is required'
          : null;
      _quantityError = (quantityMilli == null || quantityMilli == 0)
          ? 'Enter a quantity like 1 or 1.5'
          : null;
      _priceError = (price == null || price.isNegative)
          ? 'Enter a valid price'
          : null;
    });

    if (_descriptionError != null ||
        _quantityError != null ||
        _priceError != null) {
      return;
    }

    Navigator.of(context).pop(
      LineItem(
        id: widget.existing?.id ?? const Uuid().v4(),
        description: description,
        quantityMilli: quantityMilli!,
        unitPriceMinor: price!.minorUnits,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.existing == null ? 'Add item' : 'Edit item',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.md),
          VaultTextField(
            key: const Key('item-description'),
            label: 'Description',
            controller: _description,
            hint: 'e.g. UI design — homepage',
            errorText: _descriptionError,
            autofocus: widget.existing == null,
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: VaultTextField(
                  key: const Key('item-quantity'),
                  label: 'Quantity',
                  controller: _quantity,
                  hint: '1.5',
                  errorText: _quantityError,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: VaultTextField(
                  key: const Key('item-price'),
                  label: 'Unit price (${widget.currency})',
                  controller: _price,
                  hint: '100.00',
                  errorText: _priceError,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onSubmitted: (_) => _submit(),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          VaultButton(
            key: const Key('item-submit'),
            label: widget.existing == null ? 'Add Item' : 'Save Item',
            onPressed: _submit,
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
  }
}

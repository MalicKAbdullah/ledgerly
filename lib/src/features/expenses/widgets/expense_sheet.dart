import 'package:core_theme/core_theme.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:ledgerly/src/core/formats.dart';
import 'package:ledgerly/src/core/money/money.dart';
import 'package:ledgerly/src/features/clients/models/client.dart';
import 'package:ledgerly/src/features/expenses/models/expense.dart';
import 'package:ledgerly/src/features/invoices/widgets/invoice_form_fields.dart';
import 'package:uuid/uuid.dart';

/// Icon used for a category everywhere in the app (chips, list, sheet).
IconData expenseCategoryIcon(ExpenseCategory category) => switch (category) {
  ExpenseCategory.supplies => Icons.inventory_2_outlined,
  ExpenseCategory.software => Icons.terminal_outlined,
  ExpenseCategory.travel => Icons.flight_takeoff_outlined,
  ExpenseCategory.fees => Icons.account_balance_outlined,
  ExpenseCategory.other => Icons.category_outlined,
};

/// Bottom sheet for adding or editing an expense. Returns the resulting
/// [Expense] via the sheet's future, or null if cancelled.
Future<Expense?> showExpenseSheet(
  BuildContext context, {
  required String defaultCurrency,
  required List<Client> clients,
  Expense? existing,
}) {
  return showModalBottomSheet<Expense>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: _ExpenseForm(
        defaultCurrency: defaultCurrency,
        clients: clients,
        existing: existing,
      ),
    ),
  );
}

final class _ExpenseForm extends StatefulWidget {
  const _ExpenseForm({
    required this.defaultCurrency,
    required this.clients,
    this.existing,
  });

  final String defaultCurrency;
  final List<Client> clients;
  final Expense? existing;

  @override
  State<_ExpenseForm> createState() => _ExpenseFormState();
}

final class _ExpenseFormState extends State<_ExpenseForm> {
  late final TextEditingController _description;
  late final TextEditingController _amount;
  late final TextEditingController _note;

  late String _currency;
  late DateTime _date;
  late ExpenseCategory _category;
  String? _clientId;
  String? _descriptionError;
  String? _amountError;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _currency = existing?.currency ?? widget.defaultCurrency;
    final now = DateTime.now();
    _date = existing?.date ?? DateTime(now.year, now.month, now.day);
    _category = existing?.category ?? ExpenseCategory.other;
    _clientId = existing?.clientId;
    _description = TextEditingController(text: existing?.description ?? '');
    _amount = TextEditingController(
      text: existing == null ? '' : existing.amount.toDecimalString(),
    );
    _note = TextEditingController(text: existing?.note ?? '');
  }

  @override
  void dispose() {
    _description.dispose();
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  void _submit() {
    final description = _description.text.trim();
    Money? amount;
    try {
      amount = Money.parse(_amount.text, _currency);
    } on FormatException {
      amount = null;
    }

    setState(() {
      _descriptionError = description.isEmpty
          ? 'Description is required'
          : null;
      _amountError = (amount == null || amount.isNegative || amount.isZero)
          ? 'Enter an amount like 25.00'
          : null;
    });
    if (_descriptionError != null || _amountError != null) return;

    Navigator.of(context).pop(
      Expense(
        id: widget.existing?.id ?? const Uuid().v4(),
        date: _date,
        category: _category,
        description: description,
        amountMinor: amount!.minorUnits,
        currency: _currency,
        clientId: _clientId,
        note: _note.text.trim(),
        createdAt: widget.existing?.createdAt ?? DateTime.now(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.existing == null ? 'Add expense' : 'Edit expense',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.md),
          Text('Category', style: AppTextStyles.label),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              for (final category in ExpenseCategory.values)
                ChoiceChip(
                  key: Key('category-${category.name}'),
                  avatar: Icon(expenseCategoryIcon(category), size: 16),
                  label: Text(category.label),
                  selected: _category == category,
                  onSelected: (_) => setState(() => _category = category),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          VaultTextField(
            key: const Key('expense-description'),
            label: 'Description',
            controller: _description,
            hint: 'e.g. Figma subscription',
            errorText: _descriptionError,
            autofocus: widget.existing == null,
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: VaultTextField(
                  key: const Key('expense-amount'),
                  label: 'Amount ($_currency)',
                  controller: _amount,
                  hint: '25.00',
                  errorText: _amountError,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: DateField(
                  label: 'Date',
                  value: Formats.date(_date),
                  onTap: _pickDate,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          CurrencyDropdown(
            value: _currency,
            onChanged: (currency) => setState(() => _currency = currency),
          ),
          const SizedBox(height: AppSpacing.md),
          Text('Client (optional)', style: AppTextStyles.label),
          const SizedBox(height: AppSpacing.sm),
          DropdownButtonFormField<String?>(
            key: const Key('expense-client'),
            initialValue: _clientId,
            hint: const Text('Not linked to a client'),
            items: [
              const DropdownMenuItem<String?>(child: Text('No client')),
              for (final client in widget.clients)
                DropdownMenuItem<String?>(
                  value: client.id,
                  child: Text(client.name, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (id) => setState(() => _clientId = id),
          ),
          const SizedBox(height: AppSpacing.md),
          VaultTextField(
            key: const Key('expense-note'),
            label: 'Note (optional)',
            controller: _note,
            hint: 'e.g. yearly plan, split with partner',
          ),
          const SizedBox(height: AppSpacing.lg),
          VaultButton(
            key: const Key('expense-submit'),
            label: widget.existing == null ? 'Add Expense' : 'Save Expense',
            onPressed: _submit,
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
  }
}

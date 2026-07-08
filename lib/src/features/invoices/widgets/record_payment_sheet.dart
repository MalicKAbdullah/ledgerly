import 'package:core_theme/core_theme.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:ledgerly/src/core/formats.dart';
import 'package:ledgerly/src/core/money/money.dart';
import 'package:ledgerly/src/features/invoices/models/invoice.dart';
import 'package:ledgerly/src/features/invoices/models/payment.dart';
import 'package:ledgerly/src/features/invoices/services/payment_math.dart';

/// What the user entered in the record-payment sheet.
final class PaymentDraft {
  const PaymentDraft({
    required this.date,
    required this.amountMinor,
    required this.method,
    required this.note,
  });

  final DateTime date;
  final int amountMinor;
  final PaymentMethod method;
  final String note;
}

/// Bottom sheet for recording a payment against [invoice]. Returns the
/// validated draft, or null if cancelled. Overpayment is rejected here so
/// the notifier never sees an invalid amount.
Future<PaymentDraft?> showRecordPaymentSheet(
  BuildContext context, {
  required Invoice invoice,
}) {
  return showModalBottomSheet<PaymentDraft>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: _PaymentForm(invoice: invoice),
    ),
  );
}

final class _PaymentForm extends StatefulWidget {
  const _PaymentForm({required this.invoice});

  final Invoice invoice;

  @override
  State<_PaymentForm> createState() => _PaymentFormState();
}

final class _PaymentFormState extends State<_PaymentForm> {
  late final TextEditingController _amount;
  late final TextEditingController _note;
  late DateTime _date;
  PaymentMethod _method = PaymentMethod.bankTransfer;
  String? _amountError;

  Money get _balance => PaymentMath.balanceDue(widget.invoice);

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _date = DateTime(now.year, now.month, now.day);
    _amount = TextEditingController(text: _balance.toDecimalString());
    _note = TextEditingController();
  }

  @override
  void dispose() {
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
    int? amountMinor;
    try {
      amountMinor = Money.parse(
        _amount.text,
        widget.invoice.currency,
      ).minorUnits;
    } on FormatException {
      amountMinor = null;
    }

    final error = amountMinor == null
        ? 'Enter a valid amount'
        : switch (PaymentMath.validatePayment(widget.invoice, amountMinor)) {
            PaymentValidation.ok => null,
            PaymentValidation.notPositive => 'Amount must be greater than zero',
            PaymentValidation.exceedsBalance =>
              'That is more than the ${_balance.format()} still due',
            PaymentValidation.alreadyPaid => 'This invoice is already paid',
          };
    setState(() => _amountError = error);
    if (error != null) return;

    Navigator.of(context).pop(
      PaymentDraft(
        date: _date,
        amountMinor: amountMinor!,
        method: _method,
        note: _note.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Record payment', style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Balance due: ${_balance.format()}',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: VaultTextField(
                  key: const Key('payment-amount'),
                  label: 'Amount (${widget.invoice.currency})',
                  controller: _amount,
                  hint: _balance.toDecimalString(),
                  errorText: _amountError,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Date', style: AppTextStyles.label),
                    const SizedBox(height: AppSpacing.sm),
                    InkWell(
                      onTap: _pickDate,
                      borderRadius: BorderRadius.circular(
                        AppSpacing.borderRadius,
                      ),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          suffixIcon: Icon(
                            Icons.calendar_today_outlined,
                            size: 18,
                          ),
                        ),
                        child: Text(Formats.date(_date)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text('Method', style: AppTextStyles.label),
          const SizedBox(height: AppSpacing.sm),
          DropdownButtonFormField<PaymentMethod>(
            key: const Key('payment-method'),
            initialValue: _method,
            items: [
              for (final method in PaymentMethod.values)
                DropdownMenuItem(value: method, child: Text(method.label)),
            ],
            onChanged: (m) => setState(() => _method = m ?? _method),
          ),
          const SizedBox(height: AppSpacing.md),
          VaultTextField(
            label: 'Note (optional)',
            controller: _note,
            hint: 'e.g. Wire ref. 20260705-001',
          ),
          const SizedBox(height: AppSpacing.lg),
          VaultButton(
            key: const Key('payment-submit'),
            label: 'Record Payment',
            onPressed: _submit,
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
  }
}

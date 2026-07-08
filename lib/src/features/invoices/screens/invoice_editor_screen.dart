import 'package:core_theme/core_theme.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ledgerly/src/core/data/app_data.dart';
import 'package:ledgerly/src/core/formats.dart';
import 'package:ledgerly/src/core/money/money.dart';
import 'package:ledgerly/src/core/providers.dart';
import 'package:ledgerly/src/features/invoices/models/invoice.dart';
import 'package:ledgerly/src/features/invoices/models/invoice_template.dart';
import 'package:ledgerly/src/features/invoices/widgets/invoice_form_fields.dart';
import 'package:ledgerly/src/features/invoices/widgets/line_item_sheet.dart';
import 'package:uuid/uuid.dart';

/// Create or edit an invoice. Pass [invoiceId] to edit, or [clientId] to
/// pre-select a client on a new invoice.
final class InvoiceEditorScreen extends ConsumerStatefulWidget {
  const InvoiceEditorScreen({this.invoiceId, this.clientId, super.key});

  final String? invoiceId;
  final String? clientId;

  @override
  ConsumerState<InvoiceEditorScreen> createState() =>
      _InvoiceEditorScreenState();
}

final class _InvoiceEditorScreenState
    extends ConsumerState<InvoiceEditorScreen> {
  final _taxRate = TextEditingController();
  final _discountValue = TextEditingController();
  final _notes = TextEditingController();

  Invoice? _original;
  String? _clientId;
  String _currency = 'USD';
  late DateTime _issueDate;
  late DateTime _dueDate;
  List<LineItem> _items = <LineItem>[];
  DiscountType _discountType = DiscountType.none;
  InvoiceTemplateId _template = InvoiceTemplateId.classic;
  String? _validationError;
  bool _initialized = false;

  @override
  void dispose() {
    _taxRate.dispose();
    _discountValue.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _initFrom(AppData data) {
    if (_initialized) return;
    _initialized = true;

    final existing = widget.invoiceId == null
        ? null
        : data.invoiceById(widget.invoiceId!);
    _original = existing;

    final today = DateTime.now();
    _clientId = existing?.clientId ?? widget.clientId;
    _currency = existing?.currency ?? data.profile.defaultCurrency;
    _issueDate =
        existing?.issueDate ?? DateTime(today.year, today.month, today.day);
    _dueDate = existing?.dueDate ?? _issueDate.add(const Duration(days: 14));
    _items = List.of(existing?.items ?? const <LineItem>[]);
    _discountType = existing?.discountType ?? DiscountType.none;
    _template = existing?.template ?? data.profile.defaultTemplate;

    _taxRate.text = formatBasisPoints(
      existing?.taxRateBp ?? data.profile.defaultTaxRateBp,
    );
    _discountValue.text = switch (existing?.discountType ?? DiscountType.none) {
      DiscountType.none => '',
      DiscountType.percent => formatBasisPoints(existing!.discountValue),
      DiscountType.fixed => Money(
        existing!.discountValue,
        _currency,
      ).toDecimalString(),
    };
    _notes.text = existing?.notes ?? '';
  }

  Invoice _buildInvoice() {
    final taxBp = tryParseBasisPoints(_taxRate.text) ?? 0;
    final discountValue = switch (_discountType) {
      DiscountType.none => 0,
      DiscountType.percent => tryParseBasisPoints(_discountValue.text) ?? 0,
      DiscountType.fixed => _parseFixedDiscount(),
    };

    return Invoice(
      id: _original?.id ?? const Uuid().v4(),
      number: _original?.number ?? '',
      clientId: _clientId!,
      currency: _currency,
      issueDate: _issueDate,
      dueDate: _dueDate,
      items: _items,
      taxRateBp: taxBp,
      discountType: _discountType,
      discountValue: discountValue,
      notes: _notes.text.trim(),
      status: _original?.status ?? InvoiceStatus.draft,
      payments: _original?.payments ?? const [],
      template: _template,
      createdAt: _original?.createdAt ?? DateTime.now(),
      sentAt: _original?.sentAt,
      paidAt: _original?.paidAt,
      estimateId: _original?.estimateId,
    );
  }

  int _parseFixedDiscount() {
    try {
      return Money.parse(_discountValue.text, _currency).minorUnits;
    } on FormatException {
      return 0;
    }
  }

  Future<void> _save() async {
    setState(() {
      _validationError = _clientId == null
          ? 'Select a client before saving.'
          : _items.isEmpty
          ? 'Add at least one line item.'
          : null;
    });
    if (_validationError != null) return;

    final saved = await ref
        .read(appDataProvider.notifier)
        .saveInvoice(_buildInvoice());
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/invoices/${saved.id}');
    }
  }

  Future<void> _pickDate({required bool isIssue}) async {
    final initial = isIssue ? _issueDate : _dueDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (isIssue) {
        _issueDate = picked;
        if (_dueDate.isBefore(_issueDate)) _dueDate = _issueDate;
      } else {
        _dueDate = picked.isBefore(_issueDate) ? _issueDate : picked;
      }
    });
  }

  Future<void> _editItem([LineItem? existing]) async {
    final result = await showLineItemSheet(
      context,
      currency: _currency,
      existing: existing,
    );
    if (result == null) return;
    setState(() {
      final index = _items.indexWhere((i) => i.id == result.id);
      if (index >= 0) {
        _items[index] = result;
      } else {
        _items.add(result);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final asyncData = ref.watch(appDataProvider);
    final data = asyncData.valueOrNull;
    if (data == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    _initFrom(data);

    final isNew = _original == null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isNew ? 'New Invoice' : 'Edit ${_original!.number}'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          ClientDropdown(
            clients: data.clients,
            selectedId: _clientId,
            onChanged: (id) => setState(() => _clientId = id),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: DateField(
                  label: 'Issue date',
                  value: Formats.date(_issueDate),
                  onTap: () => _pickDate(isIssue: true),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: DateField(
                  label: 'Due date',
                  value: Formats.date(_dueDate),
                  onTap: () => _pickDate(isIssue: false),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          CurrencyDropdown(
            value: _currency,
            enabled: _items.isEmpty,
            onChanged: (currency) => setState(() => _currency = currency),
          ),
          const SizedBox(height: AppSpacing.lg),
          LineItemsSection(
            items: _items,
            currency: _currency,
            onAdd: _editItem,
            onEdit: _editItem,
            onDelete: (item) =>
                setState(() => _items.removeWhere((i) => i.id == item.id)),
          ),
          const SizedBox(height: AppSpacing.lg),
          TaxDiscountSection(
            taxRateController: _taxRate,
            discountController: _discountValue,
            discountType: _discountType,
            currency: _currency,
            onDiscountTypeChanged: (type) =>
                setState(() => _discountType = type),
            onChanged: () => setState(() {}),
          ),
          const SizedBox(height: AppSpacing.md),
          VaultTextField(
            label: 'Notes / payment terms',
            controller: _notes,
            hint: 'e.g. Payment due within 14 days via bank transfer.',
          ),
          const SizedBox(height: AppSpacing.lg),
          TotalsPreview(invoice: _buildPreviewInvoice()),
          if (_validationError != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              _validationError!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          VaultButton(
            key: const Key('save-invoice'),
            label: 'Save Invoice',
            onPressed: _save,
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  /// Preview uses a placeholder client id so totals render before a client
  /// is selected.
  Invoice _buildPreviewInvoice() {
    final realClientId = _clientId;
    _clientId ??= '_preview';
    final invoice = _buildInvoice();
    _clientId = realClientId;
    return invoice;
  }
}

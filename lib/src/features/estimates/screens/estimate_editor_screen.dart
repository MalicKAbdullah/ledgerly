import 'package:core_theme/core_theme.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ledgerly/src/core/data/app_data.dart';
import 'package:ledgerly/src/core/formats.dart';
import 'package:ledgerly/src/core/money/money.dart';
import 'package:ledgerly/src/core/providers.dart';
import 'package:ledgerly/src/features/estimates/models/estimate.dart';
import 'package:ledgerly/src/features/estimates/services/estimate_math.dart';
import 'package:ledgerly/src/features/invoices/models/invoice.dart';
import 'package:ledgerly/src/features/invoices/models/invoice_template.dart';
import 'package:ledgerly/src/features/invoices/widgets/invoice_form_fields.dart';
import 'package:ledgerly/src/features/invoices/widgets/line_item_sheet.dart';
import 'package:uuid/uuid.dart';

/// Create or edit an estimate. Same building blocks as the invoice editor
/// with a validity date instead of a due date.
final class EstimateEditorScreen extends ConsumerStatefulWidget {
  const EstimateEditorScreen({this.estimateId, this.clientId, super.key});

  final String? estimateId;
  final String? clientId;

  @override
  ConsumerState<EstimateEditorScreen> createState() =>
      _EstimateEditorScreenState();
}

final class _EstimateEditorScreenState
    extends ConsumerState<EstimateEditorScreen> {
  final _taxRate = TextEditingController();
  final _discountValue = TextEditingController();
  final _notes = TextEditingController();

  Estimate? _original;
  String? _clientId;
  String _currency = 'USD';
  late DateTime _issueDate;
  late DateTime _validUntil;
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

    final existing = widget.estimateId == null
        ? null
        : data.estimateById(widget.estimateId!);
    _original = existing;

    final today = DateTime.now();
    _clientId = existing?.clientId ?? widget.clientId;
    _currency = existing?.currency ?? data.profile.defaultCurrency;
    _issueDate =
        existing?.issueDate ?? DateTime(today.year, today.month, today.day);
    _validUntil =
        existing?.validUntil ?? _issueDate.add(const Duration(days: 30));
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

  Estimate _buildEstimate() {
    final taxBp = tryParseBasisPoints(_taxRate.text) ?? 0;
    final discountValue = switch (_discountType) {
      DiscountType.none => 0,
      DiscountType.percent => tryParseBasisPoints(_discountValue.text) ?? 0,
      DiscountType.fixed => _parseFixedDiscount(),
    };

    return Estimate(
      id: _original?.id ?? const Uuid().v4(),
      number: _original?.number ?? '',
      clientId: _clientId!,
      currency: _currency,
      issueDate: _issueDate,
      validUntil: _validUntil,
      items: _items,
      taxRateBp: taxBp,
      discountType: _discountType,
      discountValue: discountValue,
      notes: _notes.text.trim(),
      status: _original?.status ?? EstimateStatus.draft,
      template: _template,
      createdAt: _original?.createdAt ?? DateTime.now(),
      sentAt: _original?.sentAt,
      acceptedAt: _original?.acceptedAt,
      declinedAt: _original?.declinedAt,
      convertedInvoiceId: _original?.convertedInvoiceId,
      convertedInvoiceNumber: _original?.convertedInvoiceNumber,
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
        .saveEstimate(_buildEstimate());
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/invoices/estimates/${saved.id}');
    }
  }

  Future<void> _pickDate({required bool isIssue}) async {
    final initial = isIssue ? _issueDate : _validUntil;
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
        if (_validUntil.isBefore(_issueDate)) _validUntil = _issueDate;
      } else {
        _validUntil = picked.isBefore(_issueDate) ? _issueDate : picked;
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
        title: Text(isNew ? 'New Estimate' : 'Edit ${_original!.number}'),
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
                  label: 'Valid until',
                  value: Formats.date(_validUntil),
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
            label: 'Notes / terms',
            controller: _notes,
            hint: 'e.g. Prices valid for 30 days. 50% upfront.',
          ),
          const SizedBox(height: AppSpacing.lg),
          TotalsPreview(
            invoice: EstimateMath.shadowInvoice(_buildPreviewEstimate()),
          ),
          if (_validationError != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              _validationError!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          VaultButton(
            key: const Key('save-estimate'),
            label: 'Save Estimate',
            onPressed: _save,
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  /// Preview uses a placeholder client id so totals render before a client
  /// is selected.
  Estimate _buildPreviewEstimate() {
    final realClientId = _clientId;
    _clientId ??= '_preview';
    final estimate = _buildEstimate();
    _clientId = realClientId;
    return estimate;
  }
}

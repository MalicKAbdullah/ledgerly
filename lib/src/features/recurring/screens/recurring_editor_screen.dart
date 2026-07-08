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
import 'package:ledgerly/src/features/recurring/models/recurring_template.dart';
import 'package:ledgerly/src/features/recurring/services/recurring_materializer.dart';
import 'package:uuid/uuid.dart';

/// Create or edit a recurring schedule. Pass [templateId] to edit, or
/// [fromInvoiceId] to pre-fill everything from an existing invoice
/// ("Make recurring").
final class RecurringEditorScreen extends ConsumerStatefulWidget {
  const RecurringEditorScreen({this.templateId, this.fromInvoiceId, super.key});

  final String? templateId;
  final String? fromInvoiceId;

  @override
  ConsumerState<RecurringEditorScreen> createState() =>
      _RecurringEditorScreenState();
}

final class _RecurringEditorScreenState
    extends ConsumerState<RecurringEditorScreen> {
  final _taxRate = TextEditingController();
  final _discountValue = TextEditingController();
  final _notes = TextEditingController();
  final _dayOfMonth = TextEditingController();
  final _intervalMonths = TextEditingController();
  final _dueInDays = TextEditingController();

  RecurringTemplate? _original;
  String? _clientId;
  String _currency = 'USD';
  List<LineItem> _items = <LineItem>[];
  DiscountType _discountType = DiscountType.none;
  InvoiceTemplateId _template = InvoiceTemplateId.classic;
  RecurrenceFrequency _frequency = RecurrenceFrequency.monthly;
  late DateTime _startDate;
  DateTime? _endDate;
  bool _active = true;
  String? _validationError;
  bool _initialized = false;

  @override
  void dispose() {
    _taxRate.dispose();
    _discountValue.dispose();
    _notes.dispose();
    _dayOfMonth.dispose();
    _intervalMonths.dispose();
    _dueInDays.dispose();
    super.dispose();
  }

  void _initFrom(AppData data) {
    if (_initialized) return;
    _initialized = true;

    final existing = widget.templateId == null
        ? null
        : data.recurringTemplateById(widget.templateId!);
    _original = existing;
    final sourceInvoice = widget.fromInvoiceId == null
        ? null
        : data.invoiceById(widget.fromInvoiceId!);

    final today = DateTime.now();
    _clientId = existing?.clientId ?? sourceInvoice?.clientId;
    _currency =
        existing?.currency ??
        sourceInvoice?.currency ??
        data.profile.defaultCurrency;
    _items = List.of(existing?.items ?? sourceInvoice?.items ?? const []);
    _discountType =
        existing?.discountType ??
        sourceInvoice?.discountType ??
        DiscountType.none;
    _template =
        existing?.template ??
        sourceInvoice?.template ??
        data.profile.defaultTemplate;
    _frequency = existing?.frequency ?? RecurrenceFrequency.monthly;
    _startDate =
        existing?.startDate ?? DateTime(today.year, today.month, today.day);
    _endDate = existing?.endDate;
    _active = existing?.active ?? true;

    _taxRate.text = formatBasisPoints(
      existing?.taxRateBp ??
          sourceInvoice?.taxRateBp ??
          data.profile.defaultTaxRateBp,
    );
    final discountValue =
        existing?.discountValue ?? sourceInvoice?.discountValue ?? 0;
    _discountValue.text = switch (_discountType) {
      DiscountType.none => '',
      DiscountType.percent => formatBasisPoints(discountValue),
      DiscountType.fixed => Money(discountValue, _currency).toDecimalString(),
    };
    _notes.text = existing?.notes ?? sourceInvoice?.notes ?? '';
    _dayOfMonth.text =
        (existing?.dayOfMonth ?? sourceInvoice?.issueDate.day ?? today.day)
            .toString();
    _intervalMonths.text = (existing?.intervalMonths ?? 1).toString();
    _dueInDays.text = (existing?.dueInDays ?? 14).toString();
  }

  bool _scheduleChanged(RecurringTemplate original) =>
      original.frequency != _frequency ||
      original.dayOfMonth != _parsedDayOfMonth ||
      original.intervalMonths != _parsedIntervalMonths ||
      original.startDate != _startDate;

  int get _parsedDayOfMonth =>
      (int.tryParse(_dayOfMonth.text.trim()) ?? 1).clamp(1, 31);

  int get _parsedIntervalMonths =>
      (int.tryParse(_intervalMonths.text.trim()) ?? 1).clamp(1, 36);

  int get _parsedDueInDays =>
      (int.tryParse(_dueInDays.text.trim()) ?? 14).clamp(0, 365);

  RecurringTemplate _buildTemplate() {
    final original = _original;
    final taxBp = tryParseBasisPoints(_taxRate.text) ?? 0;
    final discountValue = switch (_discountType) {
      DiscountType.none => 0,
      DiscountType.percent => tryParseBasisPoints(_discountValue.text) ?? 0,
      DiscountType.fixed => _parseFixedDiscount(),
    };

    // Schedule edits recompute the next run from the (new) start date;
    // otherwise the advanced date is preserved so no periods re-generate.
    final nextRunDate = (original != null && !_scheduleChanged(original))
        ? original.nextRunDate
        : RecurringMaterializer.firstRunDate(
            frequency: _frequency,
            startDate: _startDate,
            dayOfMonth: _parsedDayOfMonth,
          );

    return RecurringTemplate(
      id: original?.id ?? const Uuid().v4(),
      clientId: _clientId!,
      currency: _currency,
      items: _items,
      taxRateBp: taxBp,
      discountType: _discountType,
      discountValue: discountValue,
      notes: _notes.text.trim(),
      template: _template,
      frequency: _frequency,
      dayOfMonth: _parsedDayOfMonth,
      intervalMonths: _parsedIntervalMonths,
      startDate: _startDate,
      endDate: _endDate,
      dueInDays: _parsedDueInDays,
      active: _active,
      nextRunDate: nextRunDate,
      createdAt: original?.createdAt ?? DateTime.now(),
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

    await ref
        .read(appDataProvider.notifier)
        .saveRecurringTemplate(_buildTemplate());
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/invoices/recurring');
    }
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _startDate = picked);
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate.add(const Duration(days: 365)),
      firstDate: _startDate,
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _endDate = picked);
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
        title: Text(isNew ? 'New Recurring Invoice' : 'Edit Recurring'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          ClientDropdown(
            clients: data.clients,
            selectedId: _clientId,
            onChanged: (id) => setState(() => _clientId = id),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Schedule', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<RecurrenceFrequency>(
              key: const Key('recurring-frequency'),
              segments: const [
                ButtonSegment(
                  value: RecurrenceFrequency.weekly,
                  label: Text('Weekly'),
                ),
                ButtonSegment(
                  value: RecurrenceFrequency.monthly,
                  label: Text('Monthly'),
                ),
              ],
              selected: {_frequency},
              onSelectionChanged: (selection) =>
                  setState(() => _frequency = selection.first),
            ),
          ),
          if (_frequency == RecurrenceFrequency.monthly) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: VaultTextField(
                    key: const Key('recurring-day'),
                    label: 'Day of month (1–31)',
                    controller: _dayOfMonth,
                    hint: '1',
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: VaultTextField(
                    key: const Key('recurring-interval'),
                    label: 'Every N months',
                    controller: _intervalMonths,
                    hint: '1',
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Days past a month\'s end clamp to its last day '
              '(31st → Feb 28).',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: DateField(
                  label: 'Start date',
                  value: Formats.date(_startDate),
                  onTap: _pickStartDate,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DateField(
                      label: 'End date (optional)',
                      value: _endDate == null
                          ? 'Never'
                          : Formats.date(_endDate!),
                      onTap: _pickEndDate,
                    ),
                    if (_endDate != null)
                      TextButton(
                        onPressed: () => setState(() => _endDate = null),
                        child: const Text('Clear end date'),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          VaultTextField(
            key: const Key('recurring-due-days'),
            label: 'Due in (days after issue)',
            controller: _dueInDays,
            hint: '14',
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: AppSpacing.sm),
          SwitchListTile(
            key: const Key('recurring-active'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Active'),
            subtitle: const Text(
              'Paused schedules generate nothing until resumed.',
            ),
            value: _active,
            onChanged: (value) => setState(() => _active = value),
          ),
          const SizedBox(height: AppSpacing.lg),
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
            label: 'Notes on generated invoices',
            controller: _notes,
            hint: 'e.g. Monthly retainer as agreed.',
          ),
          if (_validationError != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              _validationError!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          VaultButton(
            key: const Key('save-recurring'),
            label: 'Save Schedule',
            onPressed: _save,
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}

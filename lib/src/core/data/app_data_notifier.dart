import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledgerly/src/core/data/app_data.dart';
import 'package:ledgerly/src/core/providers.dart';
import 'package:ledgerly/src/features/backup/services/backup_service.dart';
import 'package:ledgerly/src/features/clients/models/client.dart';
import 'package:ledgerly/src/features/estimates/models/estimate.dart';
import 'package:ledgerly/src/features/expenses/models/expense.dart';
import 'package:ledgerly/src/features/invoices/models/invoice.dart';
import 'package:ledgerly/src/features/invoices/models/invoice_template.dart';
import 'package:ledgerly/src/features/invoices/models/payment.dart';
import 'package:ledgerly/src/features/invoices/services/invoice_calculator.dart';
import 'package:ledgerly/src/features/invoices/services/invoice_number_service.dart';
import 'package:ledgerly/src/features/invoices/services/payment_math.dart';
import 'package:ledgerly/src/features/recurring/models/recurring_template.dart';
import 'package:ledgerly/src/features/recurring/services/recurring_materializer.dart';
import 'package:ledgerly/src/features/settings/models/business_profile.dart';
import 'package:uuid/uuid.dart';

/// Holds the decrypted in-memory snapshot and persists (encrypt + write)
/// after every mutation.
final class AppDataNotifier extends AsyncNotifier<AppData> {
  static const _uuid = Uuid();

  RecurringRunResult? _pendingRecurringRun;

  /// The result of the recurring run performed on load, handed out once so
  /// the UI can surface a "N invoices generated" banner exactly one time.
  RecurringRunResult? takeRecurringRunResult() {
    final result = _pendingRecurringRun;
    _pendingRecurringRun = null;
    return result;
  }

  @override
  Future<AppData> build() async {
    final data = await ref.watch(ledgerStoreProvider).load();

    // Materialize any due recurring invoices (catch-up included) before
    // the first frame renders.
    final result = RecurringMaterializer.run(
      templates: data.recurringTemplates,
      existingInvoices: data.invoices,
      invoicePrefix: data.profile.invoicePrefix,
      now: ref.read(clockProvider).now(),
      newId: _uuid.v4,
    );
    if (!result.hasChanges) return data;

    final next = data.copyWith(
      invoices: [...data.invoices, ...result.newInvoices],
      recurringTemplates: result.updatedTemplates,
    );
    await ref.read(ledgerStoreProvider).save(next);
    _pendingRecurringRun = result;
    return next;
  }

  Future<void> _commit(AppData next) async {
    state = AsyncData<AppData>(next);
    await ref.read(ledgerStoreProvider).save(next);
  }

  AppData get _data => state.requireValue;

  // -- Profile ------------------------------------------------------------

  Future<void> saveProfile(BusinessProfile profile) =>
      _commit(_data.copyWith(profile: profile));

  // -- Backup -------------------------------------------------------------

  /// Applies a decoded backup: merge (by id, newer wins, profile kept) or
  /// replace the whole snapshot with the backup's contents.
  Future<void> importBackup(AppData imported, {required bool merge}) =>
      _commit(merge ? BackupService.merge(_data, imported) : imported);

  // -- Clients ------------------------------------------------------------

  Future<Client> createClient(Client Function(String id) builder) async {
    final client = builder(_uuid.v4());
    await _commit(_data.copyWith(clients: [..._data.clients, client]));
    return client;
  }

  Future<void> updateClient(Client client) async {
    final clients = [
      for (final c in _data.clients) c.id == client.id ? client : c,
    ];
    await _commit(_data.copyWith(clients: clients));
  }

  /// Deletes a client and all of their invoices.
  Future<void> deleteClient(String clientId) async {
    await _commit(
      _data.copyWith(
        clients: _data.clients.where((c) => c.id != clientId).toList(),
        invoices: _data.invoices.where((i) => i.clientId != clientId).toList(),
      ),
    );
  }

  // -- Invoices -----------------------------------------------------------

  /// Inserts or updates an invoice. New invoices (empty [Invoice.number])
  /// get the next per-year sequence number based on their issue date.
  Future<Invoice> saveInvoice(Invoice invoice) async {
    var toSave = invoice;
    if (toSave.number.isEmpty) {
      toSave = toSave.copyWith(
        number: InvoiceNumberService.next(
          existing: _data.invoices,
          prefix: _data.profile.invoicePrefix,
          year: toSave.issueDate.year,
        ),
      );
    }

    final exists = _data.invoices.any((i) => i.id == toSave.id);
    final invoices = exists
        ? [for (final i in _data.invoices) i.id == toSave.id ? toSave : i]
        : [..._data.invoices, toSave];
    await _commit(_data.copyWith(invoices: invoices));
    return toSave;
  }

  Future<void> deleteInvoice(String invoiceId) => _commit(
    _data.copyWith(
      invoices: _data.invoices.where((i) => i.id != invoiceId).toList(),
    ),
  );

  /// Creates a draft copy of an existing invoice with a fresh number,
  /// issued today, keeping the original issue->due interval.
  Future<Invoice> duplicateInvoice(String invoiceId) async {
    final source = _data.invoiceById(invoiceId);
    if (source == null) {
      throw StateError('Invoice not found: $invoiceId');
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final term = source.dueDate.difference(source.issueDate);

    final copy = Invoice(
      id: _uuid.v4(),
      number: InvoiceNumberService.next(
        existing: _data.invoices,
        prefix: _data.profile.invoicePrefix,
        year: today.year,
      ),
      clientId: source.clientId,
      currency: source.currency,
      issueDate: today,
      dueDate: today.add(term),
      items: [
        for (final item in source.items)
          LineItem(
            id: _uuid.v4(),
            description: item.description,
            quantityMilli: item.quantityMilli,
            unitPriceMinor: item.unitPriceMinor,
          ),
      ],
      taxRateBp: source.taxRateBp,
      discountType: source.discountType,
      discountValue: source.discountValue,
      notes: source.notes,
      template: source.template,
      createdAt: now,
    );
    await _commit(_data.copyWith(invoices: [..._data.invoices, copy]));
    return copy;
  }

  Future<void> setInvoiceStatus(String invoiceId, InvoiceStatus status) async {
    final invoices = [
      for (final i in _data.invoices)
        i.id == invoiceId ? i.withStatus(status, DateTime.now()) : i,
    ];
    await _commit(_data.copyWith(invoices: invoices));
  }

  /// Changes which PDF template an invoice renders with.
  Future<void> setInvoiceTemplate(
    String invoiceId,
    InvoiceTemplateId template,
  ) async {
    final invoices = [
      for (final i in _data.invoices)
        i.id == invoiceId ? i.copyWith(template: template) : i,
    ];
    await _commit(_data.copyWith(invoices: invoices));
  }

  // -- Estimates ------------------------------------------------------------

  /// Fixed prefix for estimate numbers; independent of the invoice prefix
  /// so the two sequences never collide.
  static const String estimatePrefix = 'EST';

  /// Inserts or updates an estimate. New estimates (empty number) get the
  /// next per-year `EST-YYYY-NNNN` sequence based on their issue date.
  Future<Estimate> saveEstimate(Estimate estimate) async {
    var toSave = estimate;
    if (toSave.number.isEmpty) {
      toSave = toSave.copyWith(
        number: InvoiceNumberService.nextNumber(
          existingNumbers: _data.estimates.map((e) => e.number),
          prefix: estimatePrefix,
          year: toSave.issueDate.year,
        ),
      );
    }
    final exists = _data.estimates.any((e) => e.id == toSave.id);
    final estimates = exists
        ? [for (final e in _data.estimates) e.id == toSave.id ? toSave : e]
        : [..._data.estimates, toSave];
    await _commit(_data.copyWith(estimates: estimates));
    return toSave;
  }

  Future<void> deleteEstimate(String estimateId) => _commit(
    _data.copyWith(
      estimates: _data.estimates.where((e) => e.id != estimateId).toList(),
    ),
  );

  Future<void> setEstimateStatus(
    String estimateId,
    EstimateStatus status,
  ) async {
    final estimates = [
      for (final e in _data.estimates)
        e.id == estimateId ? e.withStatus(status, DateTime.now()) : e,
    ];
    await _commit(_data.copyWith(estimates: estimates));
  }

  Future<void> setEstimateTemplate(
    String estimateId,
    InvoiceTemplateId template,
  ) async {
    final estimates = [
      for (final e in _data.estimates)
        e.id == estimateId ? e.copyWith(template: template) : e,
    ];
    await _commit(_data.copyWith(estimates: estimates));
  }

  /// Creates a fresh draft copy of an estimate: new number, issued today,
  /// same validity interval, conversion links cleared.
  Future<Estimate> duplicateEstimate(String estimateId) async {
    final source = _data.estimateById(estimateId);
    if (source == null) throw StateError('Estimate not found: $estimateId');
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final validity = source.validUntil.difference(source.issueDate);

    final copy = Estimate(
      id: _uuid.v4(),
      number: InvoiceNumberService.nextNumber(
        existingNumbers: _data.estimates.map((e) => e.number),
        prefix: estimatePrefix,
        year: today.year,
      ),
      clientId: source.clientId,
      currency: source.currency,
      issueDate: today,
      validUntil: today.add(validity),
      items: [
        for (final item in source.items)
          LineItem(
            id: _uuid.v4(),
            description: item.description,
            quantityMilli: item.quantityMilli,
            unitPriceMinor: item.unitPriceMinor,
          ),
      ],
      taxRateBp: source.taxRateBp,
      discountType: source.discountType,
      discountValue: source.discountValue,
      notes: source.notes,
      template: source.template,
      createdAt: now,
    );
    await _commit(_data.copyWith(estimates: [..._data.estimates, copy]));
    return copy;
  }

  /// One-tap conversion: creates a draft invoice copying client, line
  /// items (fresh ids), tax, discount, notes and template; links it back
  /// via `estimateId`; and marks the estimate accepted with the invoice
  /// reference. Both changes land in a single commit.
  Future<Invoice> convertEstimateToInvoice(String estimateId) async {
    final estimate = _data.estimateById(estimateId);
    if (estimate == null) throw StateError('Estimate not found: $estimateId');

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final invoice = Invoice(
      id: _uuid.v4(),
      number: InvoiceNumberService.next(
        existing: _data.invoices,
        prefix: _data.profile.invoicePrefix,
        year: today.year,
      ),
      clientId: estimate.clientId,
      currency: estimate.currency,
      issueDate: today,
      dueDate: today.add(const Duration(days: 14)),
      items: [
        for (final item in estimate.items)
          LineItem(
            id: _uuid.v4(),
            description: item.description,
            quantityMilli: item.quantityMilli,
            unitPriceMinor: item.unitPriceMinor,
          ),
      ],
      taxRateBp: estimate.taxRateBp,
      discountType: estimate.discountType,
      discountValue: estimate.discountValue,
      notes: estimate.notes,
      template: estimate.template,
      createdAt: now,
      estimateId: estimate.id,
    );

    final updatedEstimate = estimate
        .withStatus(EstimateStatus.accepted, now)
        .copyWith(
          convertedInvoiceId: invoice.id,
          convertedInvoiceNumber: invoice.number,
        );

    await _commit(
      _data.copyWith(
        invoices: [..._data.invoices, invoice],
        estimates: [
          for (final e in _data.estimates)
            e.id == estimateId ? updatedEstimate : e,
        ],
      ),
    );
    return invoice;
  }

  // -- Expenses -------------------------------------------------------------

  /// Inserts or updates an expense.
  Future<Expense> saveExpense(Expense expense) async {
    final exists = _data.expenses.any((e) => e.id == expense.id);
    final expenses = exists
        ? [for (final e in _data.expenses) e.id == expense.id ? expense : e]
        : [..._data.expenses, expense];
    await _commit(_data.copyWith(expenses: expenses));
    return expense;
  }

  Future<void> deleteExpense(String expenseId) => _commit(
    _data.copyWith(
      expenses: _data.expenses.where((e) => e.id != expenseId).toList(),
    ),
  );

  // -- Recurring templates ----------------------------------------------------

  /// Inserts or updates a recurring template, then immediately materializes
  /// anything already due (e.g. a start date of today).
  Future<RecurringTemplate> saveRecurringTemplate(
    RecurringTemplate template,
  ) async {
    final exists = _data.recurringTemplates.any((t) => t.id == template.id);
    final templates = exists
        ? [
            for (final t in _data.recurringTemplates)
              t.id == template.id ? template : t,
          ]
        : [..._data.recurringTemplates, template];

    final result = RecurringMaterializer.run(
      templates: templates,
      existingInvoices: _data.invoices,
      invoicePrefix: _data.profile.invoicePrefix,
      now: ref.read(clockProvider).now(),
      newId: _uuid.v4,
    );
    await _commit(
      _data.copyWith(
        invoices: [..._data.invoices, ...result.newInvoices],
        recurringTemplates: result.updatedTemplates,
      ),
    );
    return _data.recurringTemplateById(template.id) ?? template;
  }

  Future<void> deleteRecurringTemplate(String templateId) => _commit(
    _data.copyWith(
      recurringTemplates: _data.recurringTemplates
          .where((t) => t.id != templateId)
          .toList(),
    ),
  );

  /// Pause (false) or resume (true) a schedule. Resuming skips everything
  /// that came due while paused — the next run moves to the first
  /// occurrence after today, so no surprise catch-up invoices appear.
  Future<void> setRecurringActive(String templateId, bool active) async {
    final template = _data.recurringTemplateById(templateId);
    if (template == null) return;

    var updated = template.copyWith(active: active);
    if (active) {
      final today = ref.read(clockProvider).now();
      var next = updated.nextRunDate;
      var guard = 0;
      while (!next.isAfter(today) &&
          guard < RecurringMaterializer.maxCatchUpPerTemplate) {
        next = RecurringMaterializer.advance(updated, next);
        guard++;
      }
      updated = updated.copyWith(nextRunDate: next);
    }
    await _commit(
      _data.copyWith(
        recurringTemplates: [
          for (final t in _data.recurringTemplates)
            t.id == templateId ? updated : t,
        ],
      ),
    );
  }

  // -- Payments -------------------------------------------------------------

  /// Records a payment against an invoice. Validates via [PaymentMath]
  /// (positive amount, no overpayment) and automatically transitions the
  /// invoice to `paid` when the balance reaches zero.
  ///
  /// Throws [ArgumentError] when the payment is invalid — callers should
  /// pre-validate with [PaymentMath.validatePayment] for friendly errors.
  Future<Invoice> recordPayment(
    String invoiceId, {
    required DateTime date,
    required int amountMinor,
    PaymentMethod method = PaymentMethod.bankTransfer,
    String note = '',
  }) async {
    final invoice = _data.invoiceById(invoiceId);
    if (invoice == null) throw StateError('Invoice not found: $invoiceId');

    final validation = PaymentMath.validatePayment(invoice, amountMinor);
    if (!validation.isOk) {
      throw ArgumentError('Invalid payment: ${validation.name}');
    }

    final payment = Payment(
      id: _uuid.v4(),
      date: date,
      amountMinor: amountMinor,
      method: method,
      note: note,
    );
    var updated = invoice.copyWith(payments: [...invoice.payments, payment]);
    if (PaymentMath.balanceDue(updated).isZero) {
      updated = updated.withStatus(InvoiceStatus.paid, date);
    }

    await _commit(
      _data.copyWith(
        invoices: [
          for (final i in _data.invoices) i.id == invoiceId ? updated : i,
        ],
      ),
    );
    return updated;
  }

  /// Removes a recorded payment. If the invoice was settled and money is
  /// owed again, it reverts to `sent`.
  Future<void> removePayment(String invoiceId, String paymentId) async {
    final invoice = _data.invoiceById(invoiceId);
    if (invoice == null) return;

    var updated = invoice.copyWith(
      payments: invoice.payments.where((p) => p.id != paymentId).toList(),
    );
    if (updated.status == InvoiceStatus.paid && _hasOpenBalance(updated)) {
      updated = updated.withStatus(InvoiceStatus.sent, DateTime.now());
    }

    await _commit(
      _data.copyWith(
        invoices: [
          for (final i in _data.invoices) i.id == invoiceId ? updated : i,
        ],
      ),
    );
  }
}

/// Paid → sent reversal check: a settled invoice's balance is defined as
/// zero, so recompute against the raw total instead.
bool _hasOpenBalance(Invoice invoice) {
  final total = InvoiceCalculator.calculate(invoice).total;
  return PaymentMath.amountPaid(invoice) < total;
}

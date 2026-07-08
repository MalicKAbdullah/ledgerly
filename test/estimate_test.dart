import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledgerly/src/core/providers.dart';
import 'package:ledgerly/src/features/estimates/models/estimate.dart';
import 'package:ledgerly/src/features/estimates/services/estimate_math.dart';
import 'package:ledgerly/src/features/invoices/models/invoice.dart';
import 'package:ledgerly/src/features/invoices/models/invoice_template.dart';
import 'package:ledgerly/src/features/invoices/services/invoice_number_service.dart';

import 'helpers/fakes.dart';

Estimate makeEstimate({
  String id = 'est-1',
  String number = 'EST-2026-0001',
  String clientId = 'client-1',
  String currency = 'USD',
  DateTime? issueDate,
  DateTime? validUntil,
  List<LineItem>? items,
  int taxRateBp = 0,
  DiscountType discountType = DiscountType.none,
  int discountValue = 0,
  EstimateStatus status = EstimateStatus.draft,
  InvoiceTemplateId template = InvoiceTemplateId.classic,
  DateTime? createdAt,
  String notes = '',
}) {
  return Estimate(
    id: id,
    number: number,
    clientId: clientId,
    currency: currency,
    issueDate: issueDate ?? DateTime(2026, 6, 1),
    validUntil: validUntil ?? DateTime(2026, 7, 1),
    items:
        items ??
        const [
          LineItem(
            id: 'item-1',
            description: 'Design work',
            quantityMilli: 2000,
            unitPriceMinor: 15000,
          ),
        ],
    taxRateBp: taxRateBp,
    discountType: discountType,
    discountValue: discountValue,
    notes: notes,
    status: status,
    template: template,
    createdAt: createdAt ?? DateTime(2026, 6, 1, 9),
  );
}

void main() {
  group('estimate numbering', () {
    test('uses the EST prefix with per-year sequences', () {
      expect(
        InvoiceNumberService.nextNumber(
          existingNumbers: const [],
          prefix: 'EST',
          year: 2026,
        ),
        'EST-2026-0001',
      );
      expect(
        InvoiceNumberService.nextNumber(
          existingNumbers: const ['EST-2026-0001', 'EST-2026-0007'],
          prefix: 'EST',
          year: 2026,
        ),
        'EST-2026-0008',
      );
      expect(
        InvoiceNumberService.nextNumber(
          existingNumbers: const ['EST-2025-0042'],
          prefix: 'EST',
          year: 2026,
        ),
        'EST-2026-0001',
      );
    });

    test('estimate numbers never collide with invoice numbers', () {
      // An invoice sequence at 0009 does not bump the estimate sequence.
      expect(
        InvoiceNumberService.nextNumber(
          existingNumbers: const ['INV-2026-0009'],
          prefix: 'EST',
          year: 2026,
        ),
        'EST-2026-0001',
      );
    });
  });

  group('status / expiry matrix', () {
    final beforeExpiry = DateTime(2026, 7, 1, 23);
    final afterExpiry = DateTime(2026, 7, 2);

    test('draft and sent expire after validUntil (date-only)', () {
      for (final status in [EstimateStatus.draft, EstimateStatus.sent]) {
        final estimate = makeEstimate(status: status);
        expect(
          estimate.isExpired(beforeExpiry),
          isFalse,
          reason: '$status valid on the validity day itself',
        );
        expect(
          estimate.isExpired(afterExpiry),
          isTrue,
          reason: '$status expires the day after',
        );
      }
    });

    test('accepted and declined never expire', () {
      for (final status in [EstimateStatus.accepted, EstimateStatus.declined]) {
        final estimate = makeEstimate(
          status: EstimateStatus.sent,
        ).withStatus(status, afterExpiry);
        expect(estimate.isExpired(afterExpiry), isFalse, reason: '$status');
        expect(estimate.isExpired(DateTime(2030)), isFalse);
      }
    });

    test('withStatus records timestamps and clears the opposite one', () {
      final now = DateTime(2026, 6, 10);
      final sent = makeEstimate().withStatus(EstimateStatus.sent, now);
      expect(sent.sentAt, now);
      expect(sent.acceptedAt, isNull);

      final accepted = sent.withStatus(
        EstimateStatus.accepted,
        DateTime(2026, 6, 12),
      );
      expect(accepted.sentAt, now, reason: 'first sentAt is preserved');
      expect(accepted.acceptedAt, DateTime(2026, 6, 12));
      expect(accepted.declinedAt, isNull);

      final declined = accepted.withStatus(
        EstimateStatus.declined,
        DateTime(2026, 6, 13),
      );
      expect(declined.declinedAt, DateTime(2026, 6, 13));
      expect(declined.acceptedAt, isNull);

      final backToDraft = declined.withStatus(
        EstimateStatus.draft,
        DateTime(2026, 6, 14),
      );
      expect(backToDraft.sentAt, isNull);
      expect(backToDraft.declinedAt, isNull);
    });

    test('accepting straight from draft stamps sentAt too', () {
      final now = DateTime(2026, 6, 10);
      final accepted = makeEstimate().withStatus(EstimateStatus.accepted, now);
      expect(accepted.sentAt, now);
      expect(accepted.acceptedAt, now);
    });
  });

  group('estimate math matches invoice math', () {
    test('subtotal → discount → tax identical to InvoiceCalculator', () {
      final estimate = makeEstimate(
        taxRateBp: 750,
        discountType: DiscountType.percent,
        discountValue: 1000,
      );
      final totals = EstimateMath.totals(estimate);
      // 2 × 150.00 = 300.00, −10% = 270.00, +7.5% tax = 290.25.
      expect(totals.subtotal.minorUnits, 30000);
      expect(totals.discount.minorUnits, 3000);
      expect(totals.tax.minorUnits, 2025);
      expect(totals.total.minorUnits, 29025);
    });
  });

  group('JSON round-trip', () {
    test('all fields survive, unknown status falls back to draft', () {
      final estimate = makeEstimate(
        taxRateBp: 750,
        discountType: DiscountType.fixed,
        discountValue: 500,
        notes: 'naïve café 🌙',
      ).withStatus(EstimateStatus.accepted, DateTime(2026, 6, 15));
      final restored = Estimate.fromJson(estimate.toJson());
      expect(restored.toJson(), estimate.toJson());

      final mangled = estimate.toJson()..['status'] = 'exploded';
      expect(Estimate.fromJson(mangled).status, EstimateStatus.draft);
    });
  });

  group('conversion', () {
    ProviderContainer container(FakeVaultFile file) {
      return ProviderContainer(
        overrides: [
          secureStorageProvider.overrideWithValue(FakeSecureStorage()),
          vaultFileProvider.overrideWithValue(file),
        ],
      );
    }

    test(
      'creates a linked draft invoice and marks the estimate accepted',
      () async {
        final c = container(FakeVaultFile());
        addTearDown(c.dispose);
        final notifier = c.read(appDataProvider.notifier);
        await c.read(appDataProvider.future);

        final client = await notifier.createClient(
          (id) => makeClient(id: id, name: 'Grace'),
        );
        final estimate = await notifier.saveEstimate(
          makeEstimate(
            id: 'est-42',
            number: '',
            clientId: client.id,
            currency: 'EUR',
            taxRateBp: 750,
            discountType: DiscountType.percent,
            discountValue: 1000,
            notes: 'terms here',
            template: InvoiceTemplateId.minimal,
          ),
        );
        expect(estimate.number, 'EST-2026-0001');

        final invoice = await notifier.convertEstimateToInvoice(estimate.id);
        final data = await c.read(appDataProvider.future);

        // Field mapping.
        expect(invoice.clientId, client.id);
        expect(invoice.currency, 'EUR');
        expect(invoice.taxRateBp, 750);
        expect(invoice.discountType, DiscountType.percent);
        expect(invoice.discountValue, 1000);
        expect(invoice.notes, 'terms here');
        expect(invoice.template, InvoiceTemplateId.minimal);
        expect(invoice.status, InvoiceStatus.draft);
        expect(invoice.estimateId, estimate.id);
        expect(invoice.number, startsWith('INV-'));

        // Line items copied with fresh ids.
        expect(invoice.items, hasLength(estimate.items.length));
        expect(
          invoice.items.first.description,
          estimate.items.first.description,
        );
        expect(
          invoice.items.first.quantityMilli,
          estimate.items.first.quantityMilli,
        );
        expect(
          invoice.items.first.unitPriceMinor,
          estimate.items.first.unitPriceMinor,
        );
        expect(invoice.items.first.id, isNot(estimate.items.first.id));

        // Estimate side.
        final updated = data.estimateById(estimate.id)!;
        expect(updated.status, EstimateStatus.accepted);
        expect(updated.acceptedAt, isNotNull);
        expect(updated.convertedInvoiceId, invoice.id);
        expect(updated.convertedInvoiceNumber, invoice.number);

        // Persisted in one snapshot.
        expect(data.invoices.map((i) => i.id), contains(invoice.id));
      },
    );

    test('due date lands 14 days after the issue date', () async {
      final c = container(FakeVaultFile());
      addTearDown(c.dispose);
      final notifier = c.read(appDataProvider.notifier);
      await c.read(appDataProvider.future);
      final client = await notifier.createClient((id) => makeClient(id: id));
      final estimate = await notifier.saveEstimate(
        makeEstimate(number: '', clientId: client.id),
      );
      final invoice = await notifier.convertEstimateToInvoice(estimate.id);
      expect(invoice.dueDate.difference(invoice.issueDate).inDays, 14);
    });
  });
}

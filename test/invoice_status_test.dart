import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerly/src/features/invoices/models/invoice.dart';

import 'helpers/fakes.dart';

void main() {
  final now = DateTime(2026, 7, 3, 10, 30);

  group('Invoice.withStatus', () {
    test('draft -> sent records sentAt', () {
      final sent = makeInvoice().withStatus(InvoiceStatus.sent, now);
      expect(sent.status, InvoiceStatus.sent);
      expect(sent.sentAt, now);
      expect(sent.paidAt, isNull);
    });

    test('sent -> paid records paidAt and keeps original sentAt', () {
      final sentAt = DateTime(2026, 6, 20);
      final paid = makeInvoice(
        status: InvoiceStatus.sent,
        sentAt: sentAt,
      ).withStatus(InvoiceStatus.paid, now);
      expect(paid.status, InvoiceStatus.paid);
      expect(paid.sentAt, sentAt);
      expect(paid.paidAt, now);
    });

    test('draft -> paid records both timestamps', () {
      final paid = makeInvoice().withStatus(InvoiceStatus.paid, now);
      expect(paid.sentAt, now);
      expect(paid.paidAt, now);
    });

    test('marking sent twice keeps the first sentAt', () {
      final first = makeInvoice().withStatus(InvoiceStatus.sent, now);
      final again = first.withStatus(
        InvoiceStatus.sent,
        now.add(const Duration(days: 2)),
      );
      expect(again.sentAt, now);
    });

    test('paid -> sent clears paidAt', () {
      final paid = makeInvoice().withStatus(InvoiceStatus.paid, now);
      final back = paid.withStatus(InvoiceStatus.sent, now);
      expect(back.status, InvoiceStatus.sent);
      expect(back.paidAt, isNull);
      expect(back.sentAt, isNotNull);
    });

    test('back to draft clears all timestamps', () {
      final paid = makeInvoice().withStatus(InvoiceStatus.paid, now);
      final draft = paid.withStatus(InvoiceStatus.draft, now);
      expect(draft.sentAt, isNull);
      expect(draft.paidAt, isNull);
    });
  });

  group('Invoice.isOverdue (derived)', () {
    test('sent and past due date is overdue', () {
      final invoice = makeInvoice(
        status: InvoiceStatus.sent,
        dueDate: DateTime(2026, 7, 2),
      );
      expect(invoice.isOverdue(DateTime(2026, 7, 3, 8)), isTrue);
    });

    test('due today is not overdue', () {
      final invoice = makeInvoice(
        status: InvoiceStatus.sent,
        dueDate: DateTime(2026, 7, 3),
      );
      expect(invoice.isOverdue(DateTime(2026, 7, 3, 23, 59)), isFalse);
    });

    test('draft is never overdue', () {
      final invoice = makeInvoice(dueDate: DateTime(2020, 1, 1));
      expect(invoice.isOverdue(now), isFalse);
    });

    test('paid is never overdue', () {
      final invoice = makeInvoice(
        status: InvoiceStatus.paid,
        dueDate: DateTime(2020, 1, 1),
        paidAt: DateTime(2026, 1, 1),
      );
      expect(invoice.isOverdue(now), isFalse);
    });

    test('comparison ignores time-of-day on the due date', () {
      final invoice = makeInvoice(
        status: InvoiceStatus.sent,
        dueDate: DateTime(2026, 7, 2, 23, 59),
      );
      expect(invoice.isOverdue(DateTime(2026, 7, 3, 0, 1)), isTrue);
    });
  });

  group('Invoice JSON round-trip', () {
    test('all fields survive serialization', () {
      final original = makeInvoice(
        taxRateBp: 750,
        discountType: DiscountType.percent,
        discountValue: 1000,
        status: InvoiceStatus.sent,
        sentAt: DateTime(2026, 6, 2, 12),
        notes: 'Net 14. Bank transfer preferred.',
      );
      final restored = Invoice.fromJson(original.toJson());
      expect(restored.id, original.id);
      expect(restored.number, original.number);
      expect(restored.clientId, original.clientId);
      expect(restored.currency, original.currency);
      expect(restored.issueDate, original.issueDate);
      expect(restored.dueDate, original.dueDate);
      expect(restored.items.length, original.items.length);
      expect(
        restored.items.first.quantityMilli,
        original.items.first.quantityMilli,
      );
      expect(restored.taxRateBp, 750);
      expect(restored.discountType, DiscountType.percent);
      expect(restored.discountValue, 1000);
      expect(restored.status, InvoiceStatus.sent);
      expect(restored.sentAt, original.sentAt);
      expect(restored.paidAt, isNull);
      expect(restored.notes, original.notes);
    });
  });
}

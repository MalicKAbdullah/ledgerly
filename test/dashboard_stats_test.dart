import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerly/src/core/money/money.dart';
import 'package:ledgerly/src/features/dashboard/services/dashboard_stats.dart';
import 'package:ledgerly/src/features/invoices/models/invoice.dart';

import 'helpers/fakes.dart';

void main() {
  // "Now" is 3 July 2026; the 6-month window is Feb..Jul 2026.
  final now = DateTime(2026, 7, 3, 14);

  Invoice usd100({
    required String id,
    InvoiceStatus status = InvoiceStatus.sent,
    DateTime? dueDate,
    DateTime? paidAt,
    String currency = 'USD',
  }) {
    return makeInvoice(
      id: id,
      number: 'INV-2026-$id',
      currency: currency,
      status: status,
      dueDate: dueDate ?? DateTime(2026, 7, 20),
      paidAt: paidAt,
      items: const [
        LineItem(
          id: 'i',
          description: 'Work',
          quantityMilli: 1000,
          unitPriceMinor: 10000, // $100.00
        ),
      ],
    );
  }

  group('DashboardStats.compute', () {
    test('outstanding sums sent invoices including overdue ones', () {
      final stats = DashboardStats.compute(
        invoices: [
          usd100(id: 'a'), // sent, not due yet
          usd100(id: 'b', dueDate: DateTime(2026, 6, 1)), // overdue
          usd100(id: 'c', status: InvoiceStatus.draft),
          usd100(
            id: 'd',
            status: InvoiceStatus.paid,
            paidAt: DateTime(2026, 7, 1),
          ),
        ],
        currency: 'USD',
        now: now,
      );
      expect(stats.outstanding, const Money(20000, 'USD'));
      expect(stats.overdueCount, 1);
      expect(stats.overdueAmount, const Money(10000, 'USD'));
    });

    test('paidThisMonth only counts payments in the current month', () {
      final stats = DashboardStats.compute(
        invoices: [
          usd100(
            id: 'a',
            status: InvoiceStatus.paid,
            paidAt: DateTime(2026, 7, 1),
          ),
          usd100(
            id: 'b',
            status: InvoiceStatus.paid,
            paidAt: DateTime(2026, 6, 30, 23, 59),
          ),
        ],
        currency: 'USD',
        now: now,
      );
      expect(stats.paidThisMonth, const Money(10000, 'USD'));
    });

    test('monthlyRevenue buckets the last six months oldest-first', () {
      final stats = DashboardStats.compute(
        invoices: [
          usd100(
            id: 'feb',
            status: InvoiceStatus.paid,
            paidAt: DateTime(2026, 2, 10),
          ),
          usd100(
            id: 'jul-1',
            status: InvoiceStatus.paid,
            paidAt: DateTime(2026, 7, 2),
          ),
          usd100(
            id: 'jul-2',
            status: InvoiceStatus.paid,
            paidAt: DateTime(2026, 7, 3),
          ),
          // Outside the window: ignored.
          usd100(
            id: 'old',
            status: InvoiceStatus.paid,
            paidAt: DateTime(2026, 1, 15),
          ),
        ],
        currency: 'USD',
        now: now,
      );

      expect(stats.monthlyRevenue.length, 6);
      expect(stats.monthlyRevenue.first.month, DateTime(2026, 2));
      expect(stats.monthlyRevenue.last.month, DateTime(2026, 7));
      expect(stats.monthlyRevenue.first.total, const Money(10000, 'USD'));
      expect(stats.monthlyRevenue.last.total, const Money(20000, 'USD'));
      // Empty months are zero, not missing.
      expect(stats.monthlyRevenue[1].total, const Money.zero('USD'));
    });

    test('window crosses year boundaries correctly', () {
      final january = DateTime(2026, 1, 15);
      final stats = DashboardStats.compute(
        invoices: [
          usd100(
            id: 'aug25',
            status: InvoiceStatus.paid,
            paidAt: DateTime(2025, 8, 20),
          ),
          usd100(
            id: 'dec25',
            status: InvoiceStatus.paid,
            paidAt: DateTime(2025, 12, 31),
          ),
        ],
        currency: 'USD',
        now: january,
      );
      expect(stats.monthlyRevenue.first.month, DateTime(2025, 8));
      expect(stats.monthlyRevenue.first.total, const Money(10000, 'USD'));
      expect(stats.monthlyRevenue[4].month, DateTime(2025, 12));
      expect(stats.monthlyRevenue[4].total, const Money(10000, 'USD'));
      expect(stats.monthlyRevenue.last.month, DateTime(2026, 1));
    });

    test('other currencies are excluded and counted', () {
      final stats = DashboardStats.compute(
        invoices: [
          usd100(id: 'a'),
          usd100(id: 'b', currency: 'EUR'),
          usd100(
            id: 'c',
            currency: 'EUR',
            status: InvoiceStatus.paid,
            paidAt: DateTime(2026, 7, 1),
          ),
        ],
        currency: 'USD',
        now: now,
      );
      expect(stats.outstanding, const Money(10000, 'USD'));
      expect(stats.paidThisMonth, const Money.zero('USD'));
      expect(stats.otherCurrencyCount, 2);
    });

    test('empty data produces zeroed stats with six buckets', () {
      final stats = DashboardStats.compute(
        invoices: const [],
        currency: 'USD',
        now: now,
      );
      expect(stats.outstanding, const Money.zero('USD'));
      expect(stats.overdueCount, 0);
      expect(stats.paidThisMonth, const Money.zero('USD'));
      expect(stats.monthlyRevenue.length, 6);
      expect(stats.monthlyRevenue.every((m) => m.total.isZero), isTrue);
    });
  });
}

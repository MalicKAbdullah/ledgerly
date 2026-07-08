import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerly/src/core/money/money.dart';
import 'package:ledgerly/src/features/invoices/models/invoice.dart';
import 'package:ledgerly/src/features/invoices/services/invoice_calculator.dart';

import 'helpers/fakes.dart';

void main() {
  LineItem item(String id, int qtyMilli, int priceMinor) => LineItem(
    id: id,
    description: 'Item $id',
    quantityMilli: qtyMilli,
    unitPriceMinor: priceMinor,
  );

  group('InvoiceCalculator basics', () {
    test('empty invoice is all zeros', () {
      final totals = InvoiceCalculator.calculate(
        makeInvoice(items: const <LineItem>[]),
      );
      expect(totals.subtotal, const Money.zero('USD'));
      expect(totals.discount, const Money.zero('USD'));
      expect(totals.tax, const Money.zero('USD'));
      expect(totals.total, const Money.zero('USD'));
    });

    test('single whole-quantity item, no tax or discount', () {
      final totals = InvoiceCalculator.calculate(
        makeInvoice(items: [item('a', 2000, 5000)]), // 2 x $50
      );
      expect(totals.subtotal, const Money(10000, 'USD'));
      expect(totals.total, const Money(10000, 'USD'));
    });

    test('fractional quantities round per line', () {
      final totals = InvoiceCalculator.calculate(
        makeInvoice(
          items: [
            item('a', 1500, 10000), // 1.5 x $100 = $150.00
            item('b', 333, 100), // 0.333 x $1.00 = $0.33
            item('c', 5, 100), // 0.005 x $1.00 = $0.005 -> $0.01
          ],
        ),
      );
      expect(totals.subtotal, const Money(15034, 'USD'));
    });
  });

  group('discounts', () {
    test('percent discount with rounding', () {
      // Subtotal $99.99, 10% = $9.999 -> $10.00
      final totals = InvoiceCalculator.calculate(
        makeInvoice(
          items: [item('a', 1000, 9999)],
          discountType: DiscountType.percent,
          discountValue: 1000,
        ),
      );
      expect(totals.discount, const Money(1000, 'USD'));
      expect(totals.taxableBase, const Money(8999, 'USD'));
      expect(totals.total, const Money(8999, 'USD'));
    });

    test('100 percent discount zeroes the invoice', () {
      final totals = InvoiceCalculator.calculate(
        makeInvoice(
          items: [item('a', 1000, 12345)],
          discountType: DiscountType.percent,
          discountValue: 10000,
        ),
      );
      expect(totals.total, const Money.zero('USD'));
    });

    test('fixed discount is clamped to the subtotal', () {
      final totals = InvoiceCalculator.calculate(
        makeInvoice(
          items: [item('a', 1000, 5000)],
          discountType: DiscountType.fixed,
          discountValue: 99999,
        ),
      );
      expect(totals.discount, const Money(5000, 'USD'));
      expect(totals.total, const Money.zero('USD'));
    });

    test('negative discount value is treated as zero', () {
      final totals = InvoiceCalculator.calculate(
        makeInvoice(
          items: [item('a', 1000, 5000)],
          discountType: DiscountType.fixed,
          discountValue: -500,
        ),
      );
      expect(totals.discount, const Money.zero('USD'));
      expect(totals.total, const Money(5000, 'USD'));
    });

    test('discount value ignored when type is none', () {
      final totals = InvoiceCalculator.calculate(
        makeInvoice(discountValue: 5000),
      );
      expect(totals.discount, const Money.zero('USD'));
    });
  });

  group('tax', () {
    test('tax applies to the discounted base', () {
      // Subtotal $200, fixed discount $50, tax 10% of $150 = $15
      final totals = InvoiceCalculator.calculate(
        makeInvoice(
          items: [item('a', 2000, 10000)],
          discountType: DiscountType.fixed,
          discountValue: 5000,
          taxRateBp: 1000,
        ),
      );
      expect(totals.subtotal, const Money(20000, 'USD'));
      expect(totals.discount, const Money(5000, 'USD'));
      expect(totals.tax, const Money(1500, 'USD'));
      expect(totals.total, const Money(16500, 'USD'));
    });

    test('tax rounding half-up', () {
      // $0.02 at 25% = 0.5 cents -> 1 cent
      final totals = InvoiceCalculator.calculate(
        makeInvoice(items: [item('a', 1000, 2)], taxRateBp: 2500),
      );
      expect(totals.tax, const Money(1, 'USD'));
      expect(totals.total, const Money(3, 'USD'));
    });

    test('7.5% on odd subtotal', () {
      // $10.50 at 7.5% = 0.7875 -> $0.79
      final totals = InvoiceCalculator.calculate(
        makeInvoice(items: [item('a', 1000, 1050)], taxRateBp: 750),
      );
      expect(totals.tax, const Money(79, 'USD'));
      expect(totals.total, const Money(1129, 'USD'));
    });
  });

  group('tax x discount matrix', () {
    // Subtotal fixed at $123.45 (odd number to exercise rounding).
    final items = [item('a', 1000, 12345)];

    final cases = <(String, DiscountType, int, int, InvoiceTotals)>[
      (
        'no discount, no tax',
        DiscountType.none,
        0,
        0,
        const InvoiceTotals(
          subtotal: Money(12345, 'USD'),
          discount: Money.zero('USD'),
          taxableBase: Money(12345, 'USD'),
          tax: Money.zero('USD'),
          total: Money(12345, 'USD'),
        ),
      ),
      (
        '10% discount, 7.5% tax',
        DiscountType.percent,
        1000,
        750,
        const InvoiceTotals(
          subtotal: Money(12345, 'USD'),
          discount: Money(1235, 'USD'), // 1234.5 -> 1235
          taxableBase: Money(11110, 'USD'),
          tax: Money(833, 'USD'), // 833.25 -> 833
          total: Money(11943, 'USD'),
        ),
      ),
      (
        r'fixed $20 discount, 20% tax',
        DiscountType.fixed,
        2000,
        2000,
        const InvoiceTotals(
          subtotal: Money(12345, 'USD'),
          discount: Money(2000, 'USD'),
          taxableBase: Money(10345, 'USD'),
          tax: Money(2069, 'USD'),
          total: Money(12414, 'USD'),
        ),
      ),
    ];

    for (final (name, type, value, taxBp, expected) in cases) {
      test(name, () {
        final totals = InvoiceCalculator.calculate(
          makeInvoice(
            items: items,
            discountType: type,
            discountValue: value,
            taxRateBp: taxBp,
          ),
        );
        expect(totals.subtotal, expected.subtotal);
        expect(totals.discount, expected.discount);
        expect(totals.taxableBase, expected.taxableBase);
        expect(totals.tax, expected.tax);
        expect(totals.total, expected.total);
      });
    }

    test('printed rows always sum to printed total', () {
      for (final taxBp in [0, 500, 750, 1650, 2000]) {
        for (final discountBp in [0, 250, 1000, 3333]) {
          final totals = InvoiceCalculator.calculate(
            makeInvoice(
              items: [item('a', 1750, 9999), item('b', 333, 12345)],
              discountType: DiscountType.percent,
              discountValue: discountBp,
              taxRateBp: taxBp,
            ),
          );
          expect(
            totals.subtotal - totals.discount + totals.tax,
            totals.total,
            reason: 'tax=$taxBp discount=$discountBp',
          );
        }
      }
    });
  });

  group('zero-decimal currency', () {
    test('JPY invoice rounds to whole yen', () {
      final totals = InvoiceCalculator.calculate(
        makeInvoice(
          currency: 'JPY',
          items: [item('a', 1500, 1000)], // 1.5 x ¥1000
          taxRateBp: 1000,
        ),
      );
      expect(totals.subtotal, const Money(1500, 'JPY'));
      expect(totals.tax, const Money(150, 'JPY'));
      expect(totals.total, const Money(1650, 'JPY'));
    });
  });
}

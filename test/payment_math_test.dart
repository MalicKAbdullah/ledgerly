import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerly/src/core/money/money.dart';
import 'package:ledgerly/src/features/invoices/models/invoice.dart';
import 'package:ledgerly/src/features/invoices/models/payment.dart';
import 'package:ledgerly/src/features/invoices/services/payment_math.dart';

import 'helpers/fakes.dart';

void main() {
  // Base invoice totals $100.00 (one item, qty 1, $100 unit price).
  group('PaymentMath.amountPaid', () {
    test('is zero with no payments', () {
      expect(PaymentMath.amountPaid(makeInvoice()), const Money(0, 'USD'));
    });

    test('sums multiple payments exactly', () {
      final invoice = makeInvoice(
        payments: [
          makePayment(id: 'a', amountMinor: 3333),
          makePayment(id: 'b', amountMinor: 3333),
          makePayment(id: 'c', amountMinor: 3334),
        ],
      );
      expect(PaymentMath.amountPaid(invoice), const Money(10000, 'USD'));
    });
  });

  group('PaymentMath.balanceDue', () {
    test('equals total when nothing is paid', () {
      expect(PaymentMath.balanceDue(makeInvoice()), const Money(10000, 'USD'));
    });

    test('is reduced by partial payments', () {
      final invoice = makeInvoice(payments: [makePayment(amountMinor: 2500)]);
      expect(PaymentMath.balanceDue(invoice), const Money(7500, 'USD'));
    });

    test('never goes negative even with excess payments in the data', () {
      final invoice = makeInvoice(payments: [makePayment(amountMinor: 999999)]);
      expect(PaymentMath.balanceDue(invoice), const Money(0, 'USD'));
    });

    test(
      'is zero for a paid invoice even without payment records (legacy)',
      () {
        final invoice = makeInvoice(
          status: InvoiceStatus.paid,
          paidAt: DateTime(2026, 6, 20),
        );
        expect(PaymentMath.balanceDue(invoice), const Money(0, 'USD'));
      },
    );

    test('respects tax and discount in the total', () {
      // $100 - 10% discount = $90, +7.5% tax = $96.75
      final invoice = makeInvoice(
        taxRateBp: 750,
        discountType: DiscountType.percent,
        discountValue: 1000,
        payments: [makePayment(amountMinor: 675)],
      );
      expect(PaymentMath.balanceDue(invoice), const Money(9000, 'USD'));
    });
  });

  group('PaymentMath.isPartiallyPaid', () {
    test('false with no payments', () {
      expect(PaymentMath.isPartiallyPaid(makeInvoice()), isFalse);
    });

    test('true when some but not all is paid', () {
      final invoice = makeInvoice(payments: [makePayment(amountMinor: 1)]);
      expect(PaymentMath.isPartiallyPaid(invoice), isTrue);
    });

    test('false when invoice is fully paid', () {
      final invoice = makeInvoice(
        status: InvoiceStatus.paid,
        payments: [makePayment(amountMinor: 10000)],
      );
      expect(PaymentMath.isPartiallyPaid(invoice), isFalse);
    });
  });

  group('PaymentMath.validatePayment', () {
    test('accepts a valid partial amount', () {
      expect(
        PaymentMath.validatePayment(makeInvoice(), 5000),
        PaymentValidation.ok,
      );
    });

    test('accepts paying the exact balance', () {
      expect(
        PaymentMath.validatePayment(makeInvoice(), 10000),
        PaymentValidation.ok,
      );
    });

    test('rejects zero and negative amounts', () {
      expect(
        PaymentMath.validatePayment(makeInvoice(), 0),
        PaymentValidation.notPositive,
      );
      expect(
        PaymentMath.validatePayment(makeInvoice(), -100),
        PaymentValidation.notPositive,
      );
    });

    test('rejects overpayment by even one cent', () {
      expect(
        PaymentMath.validatePayment(makeInvoice(), 10001),
        PaymentValidation.exceedsBalance,
      );
    });

    test('rejects overpayment relative to the remaining balance', () {
      final invoice = makeInvoice(payments: [makePayment(amountMinor: 9000)]);
      expect(PaymentMath.validatePayment(invoice, 1000), PaymentValidation.ok);
      expect(
        PaymentMath.validatePayment(invoice, 1001),
        PaymentValidation.exceedsBalance,
      );
    });

    test('rejects payments on an already-paid invoice', () {
      final invoice = makeInvoice(status: InvoiceStatus.paid);
      expect(
        PaymentMath.validatePayment(invoice, 100),
        PaymentValidation.alreadyPaid,
      );
    });
  });

  group('Payment JSON', () {
    test('round-trips all fields', () {
      final payment = Payment(
        id: 'p-9',
        date: DateTime(2026, 7, 1, 14, 30),
        amountMinor: 12345,
        method: PaymentMethod.paypal,
        note: 'ref #42',
      );
      final restored = Payment.fromJson(payment.toJson());
      expect(restored.id, payment.id);
      expect(restored.date, payment.date);
      expect(restored.amountMinor, payment.amountMinor);
      expect(restored.method, payment.method);
      expect(restored.note, payment.note);
    });

    test('unknown method falls back to other', () {
      final restored = Payment.fromJson({
        'id': 'x',
        'date': '2026-01-01T00:00:00.000',
        'amountMinor': 1,
        'method': 'wire-carrier-pigeon',
      });
      expect(restored.method, PaymentMethod.other);
    });
  });

  group('Invoice JSON with payments and template', () {
    test('round-trips payments and template', () {
      final invoice = makeInvoice(
        payments: [
          makePayment(id: 'p1'),
          makePayment(id: 'p2', note: 'n'),
        ],
      ).copyWith();
      final restored = Invoice.fromJson(invoice.toJson());
      expect(restored.payments.length, 2);
      expect(restored.payments.first.id, 'p1');
      expect(restored.template, invoice.template);
    });

    test('legacy JSON without payments/template still loads', () {
      final json = makeInvoice().toJson()
        ..remove('payments')
        ..remove('template');
      final restored = Invoice.fromJson(json);
      expect(restored.payments, isEmpty);
      expect(restored.template.name, 'classic');
    });
  });
}

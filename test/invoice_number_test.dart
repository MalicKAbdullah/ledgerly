import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerly/src/features/invoices/services/invoice_number_service.dart';

import 'helpers/fakes.dart';

void main() {
  group('InvoiceNumberService', () {
    test('first invoice of a year starts at 0001', () {
      expect(
        InvoiceNumberService.next(
          existing: const [],
          prefix: 'INV',
          year: 2026,
        ),
        'INV-2026-0001',
      );
    });

    test('increments from the highest existing sequence', () {
      final existing = [
        makeInvoice(id: '1', number: 'INV-2026-0001'),
        makeInvoice(id: '2', number: 'INV-2026-0007'),
        makeInvoice(id: '3', number: 'INV-2026-0003'),
      ];
      expect(
        InvoiceNumberService.next(
          existing: existing,
          prefix: 'INV',
          year: 2026,
        ),
        'INV-2026-0008',
      );
    });

    test('sequence is per-year', () {
      final existing = [
        makeInvoice(id: '1', number: 'INV-2025-0042'),
        makeInvoice(id: '2', number: 'INV-2025-0043'),
      ];
      expect(
        InvoiceNumberService.next(
          existing: existing,
          prefix: 'INV',
          year: 2026,
        ),
        'INV-2026-0001',
      );
      expect(
        InvoiceNumberService.next(
          existing: existing,
          prefix: 'INV',
          year: 2025,
        ),
        'INV-2025-0044',
      );
    });

    test('different prefixes are independent sequences', () {
      final existing = [makeInvoice(id: '1', number: 'INV-2026-0009')];
      expect(
        InvoiceNumberService.next(
          existing: existing,
          prefix: 'ACME',
          year: 2026,
        ),
        'ACME-2026-0001',
      );
    });

    test('gaps below the max are not reused', () {
      final existing = [
        makeInvoice(id: '1', number: 'INV-2026-0001'),
        makeInvoice(id: '3', number: 'INV-2026-0003'), // 0002 was deleted
      ];
      expect(
        InvoiceNumberService.next(
          existing: existing,
          prefix: 'INV',
          year: 2026,
        ),
        'INV-2026-0004',
      );
    });

    test('sequences past 9999 keep growing without padding overflow', () {
      final existing = [makeInvoice(id: '1', number: 'INV-2026-10000')];
      expect(
        InvoiceNumberService.next(
          existing: existing,
          prefix: 'INV',
          year: 2026,
        ),
        'INV-2026-10001',
      );
    });

    test('regex metacharacters in prefix are escaped', () {
      final existing = [makeInvoice(id: '1', number: 'A.B-2026-0001')];
      expect(
        InvoiceNumberService.next(
          existing: existing,
          prefix: 'A.B',
          year: 2026,
        ),
        'A.B-2026-0002',
      );
      // 'AXB' must not match the 'A.B' pattern.
      expect(
        InvoiceNumberService.next(
          existing: [makeInvoice(id: '2', number: 'AXB-2026-0005')],
          prefix: 'A.B',
          year: 2026,
        ),
        'A.B-2026-0001',
      );
    });

    test('blank prefix falls back to INV', () {
      expect(
        InvoiceNumberService.next(existing: const [], prefix: '  ', year: 2026),
        'INV-2026-0001',
      );
    });
  });
}

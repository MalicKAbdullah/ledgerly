import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerly/src/core/data/app_data.dart';
import 'package:ledgerly/src/features/invoices/models/invoice.dart';
import 'package:ledgerly/src/features/invoices/services/csv_export_service.dart';
import 'package:ledgerly/src/features/invoices/services/reminder_service.dart';
import 'package:ledgerly/src/features/settings/models/business_profile.dart';

import 'helpers/fakes.dart';

void main() {
  final now = DateTime(2026, 7, 5);

  group('CsvExportService', () {
    test('produces header plus one row per invoice, oldest first', () {
      final data = AppData(
        clients: [makeClient()],
        invoices: [
          makeInvoice(
            id: 'b',
            number: 'INV-2026-0002',
            issueDate: DateTime(2026, 6, 2),
            dueDate: DateTime(2026, 7, 20), // not yet due at `now`
            status: InvoiceStatus.sent,
            sentAt: DateTime(2026, 6, 2),
            payments: [makePayment(amountMinor: 2500)],
          ),
          makeInvoice(
            id: 'a',
            number: 'INV-2026-0001',
            issueDate: DateTime(2026, 6, 1),
          ),
        ],
      );

      final csv = CsvExportService.buildCsv(
        invoices: data.invoices,
        data: data,
        now: now,
      );
      final lines = csv.split('\r\n');

      expect(lines, hasLength(3));
      expect(lines[0], CsvExportService.header);
      expect(
        lines[1],
        'INV-2026-0001,Ada Lovelace,2026-06-01,2026-06-15,Draft,USD,'
        '100.00,0.00,100.00',
      );
      expect(
        lines[2],
        'INV-2026-0002,Ada Lovelace,2026-06-02,2026-07-20,Partially paid,'
        'USD,100.00,25.00,75.00',
      );
    });

    test('derives Overdue and Paid statuses', () {
      final data = AppData(
        clients: [makeClient()],
        invoices: [
          makeInvoice(
            id: 'late',
            number: 'INV-2026-0009',
            status: InvoiceStatus.sent,
            sentAt: DateTime(2026, 6, 1),
            dueDate: DateTime(2026, 6, 15),
          ),
          makeInvoice(
            id: 'done',
            number: 'INV-2026-0010',
            status: InvoiceStatus.paid,
            paidAt: DateTime(2026, 6, 20),
          ),
        ],
      );
      final csv = CsvExportService.buildCsv(
        invoices: data.invoices,
        data: data,
        now: now,
      );
      expect(csv, contains(',Overdue,'));
      expect(csv, contains(',Paid,'));
      // A paid invoice's balance is always zero.
      expect(csv.split('\r\n').last, endsWith('100.00,0.00,0.00'));
    });

    test('escapes commas, quotes, and newlines per RFC 4180', () {
      expect(CsvExportService.escape('plain'), 'plain');
      expect(CsvExportService.escape('a,b'), '"a,b"');
      expect(CsvExportService.escape('say "hi"'), '"say ""hi"""');
      expect(CsvExportService.escape('line1\nline2'), '"line1\nline2"');

      final data = AppData(
        clients: [makeClient(id: 'client-1', name: 'Doe, Jane "JD"')],
        invoices: [makeInvoice()],
      );
      final csv = CsvExportService.buildCsv(
        invoices: data.invoices,
        data: data,
        now: now,
      );
      expect(csv, contains('"Doe, Jane ""JD"""'));
    });

    test('unknown client falls back to Unknown', () {
      final data = AppData(invoices: [makeInvoice(clientId: 'ghost')]);
      final csv = CsvExportService.buildCsv(
        invoices: data.invoices,
        data: data,
        now: now,
      );
      expect(csv, contains(',Unknown,'));
    });
  });

  group('ReminderService', () {
    const profile = BusinessProfile(businessName: 'Analytical Engines');

    test('mentions number, open balance, and due date', () {
      final invoice = makeInvoice(
        status: InvoiceStatus.sent,
        sentAt: DateTime(2026, 6, 1),
        dueDate: DateTime(2026, 7, 20),
        payments: [makePayment(amountMinor: 2500)],
      );
      final text = ReminderService.buildReminderText(
        profile: profile,
        client: makeClient(),
        invoice: invoice,
        now: now,
      );
      expect(text, contains('Hi Ada Lovelace'));
      expect(text, contains('INV-2026-0001'));
      expect(text, contains(r'$75.00')); // balance, not total
      expect(text, contains('is due on'));
      expect(text, contains('Analytical Engines'));
    });

    test('switches to past tense when overdue', () {
      final invoice = makeInvoice(
        status: InvoiceStatus.sent,
        sentAt: DateTime(2026, 6, 1),
        dueDate: DateTime(2026, 6, 15),
      );
      final text = ReminderService.buildReminderText(
        profile: profile,
        client: makeClient(),
        invoice: invoice,
        now: now,
      );
      expect(text, contains('was due on'));
    });
  });
}

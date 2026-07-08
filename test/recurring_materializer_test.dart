import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledgerly/src/core/providers.dart';
import 'package:ledgerly/src/features/invoices/models/invoice.dart';
import 'package:ledgerly/src/features/recurring/models/recurring_template.dart';
import 'package:ledgerly/src/features/recurring/services/recurring_materializer.dart';

import 'helpers/fakes.dart';

RecurringTemplate makeTemplate({
  String id = 'rt-1',
  String clientId = 'client-1',
  String currency = 'USD',
  RecurrenceFrequency frequency = RecurrenceFrequency.monthly,
  int dayOfMonth = 1,
  int intervalMonths = 1,
  DateTime? startDate,
  DateTime? endDate,
  int dueInDays = 14,
  bool active = true,
  DateTime? nextRunDate,
}) {
  final start = startDate ?? DateTime(2026, 1, 1);
  return RecurringTemplate(
    id: id,
    clientId: clientId,
    currency: currency,
    items: const [
      LineItem(
        id: 'item-1',
        description: 'Monthly retainer',
        quantityMilli: 1000,
        unitPriceMinor: 50000,
      ),
    ],
    taxRateBp: 750,
    frequency: frequency,
    dayOfMonth: dayOfMonth,
    intervalMonths: intervalMonths,
    startDate: start,
    endDate: endDate,
    dueInDays: dueInDays,
    active: active,
    nextRunDate:
        nextRunDate ??
        RecurringMaterializer.firstRunDate(
          frequency: frequency,
          startDate: start,
          dayOfMonth: dayOfMonth,
        ),
    createdAt: DateTime(2026, 1, 1),
  );
}

int _seq = 0;
String nextId() => 'gen-${_seq++}';

RecurringRunResult run(
  List<RecurringTemplate> templates, {
  required DateTime now,
  List<Invoice> existing = const [],
}) {
  return RecurringMaterializer.run(
    templates: templates,
    existingInvoices: existing,
    invoicePrefix: 'INV',
    now: now,
    newId: nextId,
  );
}

void main() {
  setUp(() => _seq = 0);

  group('advance — month-end clamping', () {
    test('day 31 anchors: Jan 31 → Feb 28 → Mar 31 (non-leap 2027)', () {
      final t = makeTemplate(dayOfMonth: 31);
      final feb = RecurringMaterializer.advance(t, DateTime(2027, 1, 31));
      expect(feb, DateTime(2027, 2, 28));
      final mar = RecurringMaterializer.advance(t, feb);
      expect(mar, DateTime(2027, 3, 31), reason: 'anchor day is preserved');
    });

    test('day 31 clamps to Feb 29 in a leap year (2028)', () {
      final t = makeTemplate(dayOfMonth: 31);
      expect(
        RecurringMaterializer.advance(t, DateTime(2028, 1, 31)),
        DateTime(2028, 2, 29),
      );
    });

    test('day 30 clamps only in February', () {
      final t = makeTemplate(dayOfMonth: 30);
      expect(
        RecurringMaterializer.advance(t, DateTime(2027, 1, 30)),
        DateTime(2027, 2, 28),
      );
      expect(
        RecurringMaterializer.advance(t, DateTime(2027, 4, 30)),
        DateTime(2027, 5, 30),
      );
    });

    test('every 3 months crosses the year boundary', () {
      final t = makeTemplate(dayOfMonth: 15, intervalMonths: 3);
      expect(
        RecurringMaterializer.advance(t, DateTime(2026, 11, 15)),
        DateTime(2027, 2, 15),
      );
    });

    test('weekly advances exactly 7 calendar days, across years', () {
      final t = makeTemplate(frequency: RecurrenceFrequency.weekly);
      expect(
        RecurringMaterializer.advance(t, DateTime(2026, 12, 28)),
        DateTime(2027, 1, 4),
      );
    });
  });

  group('firstRunDate', () {
    test('weekly starts on the start date', () {
      expect(
        RecurringMaterializer.firstRunDate(
          frequency: RecurrenceFrequency.weekly,
          startDate: DateTime(2026, 7, 9),
          dayOfMonth: 1,
        ),
        DateTime(2026, 7, 9),
      );
    });

    test('monthly uses the anchor day in the start month when still ahead', () {
      expect(
        RecurringMaterializer.firstRunDate(
          frequency: RecurrenceFrequency.monthly,
          startDate: DateTime(2026, 7, 9),
          dayOfMonth: 15,
        ),
        DateTime(2026, 7, 15),
      );
    });

    test('monthly rolls to next month when the anchor day already passed', () {
      expect(
        RecurringMaterializer.firstRunDate(
          frequency: RecurrenceFrequency.monthly,
          startDate: DateTime(2026, 7, 20),
          dayOfMonth: 15,
        ),
        DateTime(2026, 8, 15),
      );
    });

    test('monthly clamps the anchor in the start month', () {
      expect(
        RecurringMaterializer.firstRunDate(
          frequency: RecurrenceFrequency.monthly,
          startDate: DateTime(2027, 2, 1),
          dayOfMonth: 31,
        ),
        DateTime(2027, 2, 28),
      );
    });
  });

  group('run — generation and catch-up', () {
    test('nothing due generates nothing and keeps templates untouched', () {
      final t = makeTemplate(nextRunDate: DateTime(2026, 8, 1));
      final result = run([t], now: DateTime(2026, 7, 7));
      expect(result.hasChanges, isFalse);
      expect(result.updatedTemplates.single.nextRunDate, DateTime(2026, 8, 1));
    });

    test('a due template generates one invoice and advances', () {
      final t = makeTemplate(nextRunDate: DateTime(2026, 7, 1));
      final result = run([t], now: DateTime(2026, 7, 7));
      expect(result.generatedCount, 1);

      final invoice = result.newInvoices.single;
      expect(invoice.issueDate, DateTime(2026, 7, 1));
      expect(invoice.dueDate, DateTime(2026, 7, 15));
      expect(invoice.number, 'INV-2026-0001');
      expect(invoice.status, InvoiceStatus.draft);
      expect(invoice.clientId, 'client-1');
      expect(invoice.taxRateBp, 750);
      expect(invoice.items.single.description, 'Monthly retainer');
      expect(
        invoice.items.single.id,
        isNot('item-1'),
        reason: 'line items get fresh ids',
      );

      expect(result.updatedTemplates.single.nextRunDate, DateTime(2026, 8, 1));
    });

    test('catch-up across a year boundary: app closed Nov 10 → reopened '
        'Feb 20 generates Dec/Jan/Feb with correct dates and numbers', () {
      final t = makeTemplate(dayOfMonth: 1, nextRunDate: DateTime(2026, 12, 1));
      final existing = [makeInvoice(id: 'x', number: 'INV-2026-0041')];
      final result = run([t], now: DateTime(2027, 2, 20), existing: existing);

      expect(result.generatedCount, 3);
      expect(result.newInvoices.map((i) => i.issueDate).toList(), [
        DateTime(2026, 12, 1),
        DateTime(2027, 1, 1),
        DateTime(2027, 2, 1),
      ]);
      // Numbering restarts per year and continues within a year.
      expect(result.newInvoices.map((i) => i.number).toList(), [
        'INV-2026-0042',
        'INV-2027-0001',
        'INV-2027-0002',
      ]);
      expect(result.updatedTemplates.single.nextRunDate, DateTime(2027, 3, 1));
      expect(result.summary, '3 invoices generated from recurring schedules');
    });

    test('weekly catch-up generates every missed week', () {
      final t = makeTemplate(
        frequency: RecurrenceFrequency.weekly,
        nextRunDate: DateTime(2026, 6, 15),
      );
      final result = run([t], now: DateTime(2026, 7, 7));
      expect(result.newInvoices.map((i) => i.issueDate).toList(), [
        DateTime(2026, 6, 15),
        DateTime(2026, 6, 22),
        DateTime(2026, 6, 29),
        DateTime(2026, 7, 6),
      ]);
      expect(result.updatedTemplates.single.nextRunDate, DateTime(2026, 7, 13));
    });

    test('month-end clamping during catch-up keeps the day-31 anchor', () {
      final t = makeTemplate(
        dayOfMonth: 31,
        nextRunDate: DateTime(2026, 12, 31),
      );
      final result = run([t], now: DateTime(2027, 4, 1));
      expect(result.newInvoices.map((i) => i.issueDate).toList(), [
        DateTime(2026, 12, 31),
        DateTime(2027, 1, 31),
        DateTime(2027, 2, 28),
        DateTime(2027, 3, 31),
      ]);
    });

    test('endDate stops generation, even mid catch-up', () {
      final t = makeTemplate(
        dayOfMonth: 1,
        nextRunDate: DateTime(2026, 5, 1),
        endDate: DateTime(2026, 6, 15),
      );
      final result = run([t], now: DateTime(2026, 9, 1));
      expect(
        result.newInvoices.map((i) => i.issueDate).toList(),
        [DateTime(2026, 5, 1), DateTime(2026, 6, 1)],
        reason: 'July 1 falls after the end date',
      );
    });

    test('paused templates generate nothing and do not advance', () {
      final t = makeTemplate(active: false, nextRunDate: DateTime(2026, 1, 1));
      final result = run([t], now: DateTime(2026, 7, 7));
      expect(result.hasChanges, isFalse);
      expect(result.updatedTemplates.single.nextRunDate, DateTime(2026, 1, 1));
    });

    test('due on exactly today generates today', () {
      final t = makeTemplate(nextRunDate: DateTime(2026, 7, 7));
      final result = run([t], now: DateTime(2026, 7, 7, 23, 15));
      expect(result.generatedCount, 1);
      expect(result.newInvoices.single.issueDate, DateTime(2026, 7, 7));
    });

    test('multiple templates share one number sequence without collisions', () {
      final a = makeTemplate(id: 'a', nextRunDate: DateTime(2026, 7, 1));
      final b = makeTemplate(id: 'b', nextRunDate: DateTime(2026, 7, 3));
      final result = run([a, b], now: DateTime(2026, 7, 7));
      final numbers = result.newInvoices.map((i) => i.number).toSet();
      expect(numbers, hasLength(2), reason: 'no duplicate numbers');
    });

    test('runaway schedules are capped per run', () {
      final t = makeTemplate(
        frequency: RecurrenceFrequency.weekly,
        nextRunDate: DateTime(2020, 1, 6),
      );
      final result = run([t], now: DateTime(2026, 7, 7));
      expect(
        result.generatedCount,
        RecurringMaterializer.maxCatchUpPerTemplate,
      );
    });

    test('single invoice summary is singular', () {
      final t = makeTemplate(nextRunDate: DateTime(2026, 7, 1));
      final result = run([t], now: DateTime(2026, 7, 7));
      expect(result.summary, '1 invoice generated from recurring schedules');
    });
  });

  group('notifier integration (fake clock)', () {
    test('materializes due invoices on load and persists them', () async {
      final file = FakeVaultFile();
      final storage = FakeSecureStorage();
      final clock = FakeClock(DateTime(2026, 7, 7, 9));

      // Seed a vault containing one active template due twice by now.
      final seedContainer = ProviderContainer(
        overrides: [
          secureStorageProvider.overrideWithValue(storage),
          vaultFileProvider.overrideWithValue(file),
          clockProvider.overrideWithValue(FakeClock(DateTime(2026, 5, 20))),
        ],
      );
      await seedContainer.read(appDataProvider.future);
      final notifier = seedContainer.read(appDataProvider.notifier);
      final client = await notifier.createClient((id) => makeClient(id: id));
      await notifier.saveRecurringTemplate(
        makeTemplate(
          clientId: client.id,
          dayOfMonth: 1,
          startDate: DateTime(2026, 6, 1),
          nextRunDate: DateTime(2026, 6, 1),
        ),
      );
      seedContainer.dispose();

      // Fresh app start on Jul 7: June 1 + July 1 must materialize.
      final container = ProviderContainer(
        overrides: [
          secureStorageProvider.overrideWithValue(storage),
          vaultFileProvider.overrideWithValue(file),
          clockProvider.overrideWithValue(clock),
        ],
      );
      addTearDown(container.dispose);

      final data = await container.read(appDataProvider.future);
      expect(data.invoices, hasLength(2));
      expect(data.invoices.map((i) => i.issueDate).toList(), [
        DateTime(2026, 6, 1),
        DateTime(2026, 7, 1),
      ]);
      expect(data.recurringTemplates.single.nextRunDate, DateTime(2026, 8, 1));

      final result = container
          .read(appDataProvider.notifier)
          .takeRecurringRunResult();
      expect(result, isNotNull);
      expect(result!.generatedCount, 2);
      expect(
        container.read(appDataProvider.notifier).takeRecurringRunResult(),
        isNull,
        reason: 'the summary is handed out exactly once',
      );

      // A second cold start generates nothing new.
      final again = ProviderContainer(
        overrides: [
          secureStorageProvider.overrideWithValue(storage),
          vaultFileProvider.overrideWithValue(file),
          clockProvider.overrideWithValue(clock),
        ],
      );
      addTearDown(again.dispose);
      final dataAgain = await again.read(appDataProvider.future);
      expect(dataAgain.invoices, hasLength(2));
      expect(
        again.read(appDataProvider.notifier).takeRecurringRunResult(),
        isNull,
      );
    });

    test('resuming a paused schedule skips missed periods', () async {
      final file = FakeVaultFile();
      final clock = FakeClock(DateTime(2026, 7, 7));
      final container = ProviderContainer(
        overrides: [
          secureStorageProvider.overrideWithValue(FakeSecureStorage()),
          vaultFileProvider.overrideWithValue(file),
          clockProvider.overrideWithValue(clock),
        ],
      );
      addTearDown(container.dispose);
      await container.read(appDataProvider.future);
      final notifier = container.read(appDataProvider.notifier);

      final client = await notifier.createClient((id) => makeClient(id: id));
      final template = await notifier.saveRecurringTemplate(
        makeTemplate(
          clientId: client.id,
          active: false,
          dayOfMonth: 1,
          startDate: DateTime(2026, 3, 1),
          nextRunDate: DateTime(2026, 3, 1),
        ),
      );

      await notifier.setRecurringActive(template.id, true);
      final data = await container.read(appDataProvider.future);
      expect(data.invoices, isEmpty, reason: 'no surprise catch-up');
      expect(
        data.recurringTemplates.single.nextRunDate,
        DateTime(2026, 8, 1),
        reason: 'resumes at the first occurrence after today',
      );
    });
  });
}

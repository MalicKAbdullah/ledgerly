import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerly/src/core/data/app_data.dart';
import 'package:ledgerly/src/features/expenses/models/expense.dart';
import 'package:ledgerly/src/features/expenses/services/expense_csv_service.dart';

import 'helpers/fakes.dart';

Expense expense({
  required String id,
  DateTime? date,
  String description = 'Stock photos',
  ExpenseCategory category = ExpenseCategory.supplies,
  int amountMinor = 1999,
  String currency = 'USD',
  String? clientId,
  String note = '',
}) {
  return Expense(
    id: id,
    date: date ?? DateTime(2026, 7, 2),
    category: category,
    description: description,
    amountMinor: amountMinor,
    currency: currency,
    clientId: clientId,
    note: note,
    createdAt: DateTime(2026, 7, 2),
  );
}

void main() {
  test('header and rows are sorted by date with ISO dates', () {
    final data = AppData(clients: [makeClient()]);
    final csv = ExpenseCsvService.buildCsv(
      expenses: [
        expense(id: 'b', date: DateTime(2026, 7, 5), amountMinor: 500),
        expense(id: 'a', date: DateTime(2026, 6, 1), amountMinor: 12050),
      ],
      data: data,
    );
    final lines = csv.split('\r\n');
    expect(
      lines.first,
      'Date,Category,Description,Client,Currency,Amount,Note',
    );
    expect(lines[1], '2026-06-01,Supplies,Stock photos,,USD,120.50,');
    expect(lines[2], '2026-07-05,Supplies,Stock photos,,USD,5.00,');
  });

  test('client link resolves to the client name', () {
    final data = AppData(
      clients: [makeClient(id: 'client-1', name: 'Ada')],
    );
    final csv = ExpenseCsvService.buildCsv(
      expenses: [expense(id: 'a', clientId: 'client-1')],
      data: data,
    );
    expect(csv.split('\r\n')[1], contains(',Ada,'));
  });

  test('fields with commas and quotes are RFC 4180 escaped', () {
    final csv = ExpenseCsvService.buildCsv(
      expenses: [
        expense(
          id: 'a',
          description: 'Flights, "economy"',
          category: ExpenseCategory.travel,
          note: 'client visit, day 1',
        ),
      ],
      data: const AppData(),
    );
    final row = csv.split('\r\n')[1];
    expect(row, contains('"Flights, ""economy"""'));
    expect(row, contains('"client visit, day 1"'));
  });

  test('non-default currencies keep their own currency column', () {
    final csv = ExpenseCsvService.buildCsv(
      expenses: [expense(id: 'a', currency: 'EUR', amountMinor: 300)],
      data: const AppData(),
    );
    expect(csv.split('\r\n')[1], contains(',EUR,3.00,'));
  });
}

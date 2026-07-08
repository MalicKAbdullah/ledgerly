import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerly/src/core/money/money.dart';
import 'package:ledgerly/src/features/expenses/models/expense.dart';
import 'package:ledgerly/src/features/expenses/services/expense_stats.dart';

Expense makeExpense({
  String id = 'e1',
  DateTime? date,
  ExpenseCategory category = ExpenseCategory.software,
  String description = 'Subscription',
  int amountMinor = 2500,
  String currency = 'USD',
  String? clientId,
}) {
  return Expense(
    id: id,
    date: date ?? DateTime(2026, 7, 3),
    category: category,
    description: description,
    amountMinor: amountMinor,
    currency: currency,
    clientId: clientId,
    createdAt: date ?? DateTime(2026, 7, 3),
  );
}

void main() {
  final now = DateTime(2026, 7, 15);

  group('ExpenseStats.compute', () {
    test('sums the current calendar month only', () {
      final stats = ExpenseStats.compute(
        expenses: [
          makeExpense(id: 'a', date: DateTime(2026, 7, 1), amountMinor: 1000),
          makeExpense(id: 'b', date: DateTime(2026, 7, 31), amountMinor: 250),
          makeExpense(id: 'c', date: DateTime(2026, 6, 30), amountMinor: 9999),
        ],
        currency: 'USD',
        now: now,
      );
      expect(stats.thisMonth, const Money(1250, 'USD'));
    });

    test('builds six aligned month buckets, oldest first', () {
      final stats = ExpenseStats.compute(
        expenses: [
          makeExpense(id: 'a', date: DateTime(2026, 2, 10), amountMinor: 100),
          makeExpense(id: 'b', date: DateTime(2026, 6, 1), amountMinor: 200),
          makeExpense(id: 'c', date: DateTime(2026, 7, 4), amountMinor: 300),
          // Outside the window — ignored.
          makeExpense(id: 'd', date: DateTime(2026, 1, 31), amountMinor: 999),
        ],
        currency: 'USD',
        now: now,
      );

      expect(stats.monthlyTotals, hasLength(6));
      expect(stats.monthlyTotals.first.month, DateTime(2026, 2));
      expect(stats.monthlyTotals.last.month, DateTime(2026, 7));
      expect(stats.monthlyTotals.map((m) => m.total.minorUnits).toList(), [
        100,
        0,
        0,
        0,
        200,
        300,
      ]);
    });

    test('expenses in other currencies are excluded and counted', () {
      final stats = ExpenseStats.compute(
        expenses: [
          makeExpense(id: 'a', amountMinor: 1000),
          makeExpense(id: 'b', currency: 'EUR', amountMinor: 5000),
          makeExpense(id: 'c', currency: 'PKR', amountMinor: 90000),
        ],
        currency: 'USD',
        now: now,
      );
      expect(stats.thisMonth, const Money(1000, 'USD'));
      expect(stats.otherCurrencyCount, 2);
      expect(stats.monthlyTotals.last.total, const Money(1000, 'USD'));
    });

    test('no expenses produce zeroed buckets', () {
      final stats = ExpenseStats.compute(
        expenses: const [],
        currency: 'USD',
        now: now,
      );
      expect(stats.thisMonth.isZero, isTrue);
      expect(stats.monthlyTotals.every((m) => m.total.isZero), isTrue);
      expect(stats.otherCurrencyCount, 0);
    });

    test('profit = paid revenue − expenses can go negative', () {
      final revenue = const Money(5000, 'USD');
      final stats = ExpenseStats.compute(
        expenses: [makeExpense(amountMinor: 7500)],
        currency: 'USD',
        now: now,
      );
      final profit = revenue - stats.thisMonth;
      expect(profit, const Money(-2500, 'USD'));
      expect(profit.isNegative, isTrue);
    });
  });

  group('Expense JSON', () {
    test('round-trips including optional fields', () {
      final expense = makeExpense(clientId: 'client-1');
      final restored = Expense.fromJson(expense.toJson());
      expect(restored.toJson(), expense.toJson());
      expect(restored.clientId, 'client-1');
    });

    test('unknown category name falls back to other', () {
      final json = makeExpense().toJson()..['category'] = 'crypto';
      expect(Expense.fromJson(json).category, ExpenseCategory.other);
    });
  });
}

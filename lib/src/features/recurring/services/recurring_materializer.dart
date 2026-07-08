import 'package:flutter/foundation.dart';
import 'package:ledgerly/src/features/invoices/models/invoice.dart';
import 'package:ledgerly/src/features/invoices/services/invoice_number_service.dart';
import 'package:ledgerly/src/features/recurring/models/recurring_template.dart';

/// Outcome of one materializer run.
@immutable
final class RecurringRunResult {
  const RecurringRunResult({
    required this.newInvoices,
    required this.updatedTemplates,
  });

  /// Freshly generated draft invoices, oldest issue date first.
  final List<Invoice> newInvoices;

  /// The full template list with advanced `nextRunDate`s.
  final List<RecurringTemplate> updatedTemplates;

  int get generatedCount => newInvoices.length;
  bool get hasChanges => newInvoices.isNotEmpty;

  /// Snackbar copy, e.g. "2 invoices generated from recurring schedules".
  String get summary => generatedCount == 1
      ? '1 invoice generated from recurring schedules'
      : '$generatedCount invoices generated from recurring schedules';
}

/// Pure date math + invoice generation for recurring templates. Runs on
/// app open: every due period since the last run is materialized as a real
/// draft invoice (catch-up), each with the correct issue date and the next
/// sequential number, and `nextRunDate` advances past today.
abstract final class RecurringMaterializer {
  /// Safety valve against runaway loops from corrupt dates: at most this
  /// many catch-up invoices are generated per template per run.
  static const int maxCatchUpPerTemplate = 60;

  static RecurringRunResult run({
    required List<RecurringTemplate> templates,
    required List<Invoice> existingInvoices,
    required String invoicePrefix,
    required DateTime now,
    required String Function() newId,
  }) {
    final today = _dateOnly(now);
    final numbers = existingInvoices.map((i) => i.number).toList();
    final generated = <Invoice>[];
    final updatedTemplates = <RecurringTemplate>[];

    for (final template in templates) {
      if (!template.active) {
        updatedTemplates.add(template);
        continue;
      }

      var next = _dateOnly(template.nextRunDate);
      final end = template.endDate == null
          ? null
          : _dateOnly(template.endDate!);
      var count = 0;

      while (!next.isAfter(today) && count < maxCatchUpPerTemplate) {
        if (end != null && next.isAfter(end)) break;

        final number = InvoiceNumberService.nextNumber(
          existingNumbers: numbers,
          prefix: invoicePrefix,
          year: next.year,
        );
        numbers.add(number);
        generated.add(_materialize(template, next, number, newId, now));
        next = advance(template, next);
        count++;
      }

      updatedTemplates.add(
        next == _dateOnly(template.nextRunDate)
            ? template
            : template.copyWith(nextRunDate: next),
      );
    }

    generated.sort((a, b) => a.issueDate.compareTo(b.issueDate));
    return RecurringRunResult(
      newInvoices: generated,
      updatedTemplates: updatedTemplates,
    );
  }

  /// The run date after [from] for [template]'s schedule.
  ///
  /// Weekly advances exactly 7 calendar days. Monthly advances
  /// `intervalMonths` months, landing on the anchor `dayOfMonth` clamped to
  /// that month's length — the anchor is preserved, so day 31 gives
  /// Jan 31 → Feb 28 (29 in leap years) → Mar 31.
  static DateTime advance(RecurringTemplate template, DateTime from) {
    switch (template.frequency) {
      case RecurrenceFrequency.weekly:
        return DateTime(from.year, from.month, from.day + 7);
      case RecurrenceFrequency.monthly:
        final interval = template.intervalMonths < 1
            ? 1
            : template.intervalMonths;
        return clampToMonth(
          from.year,
          from.month + interval,
          template.dayOfMonth,
        );
    }
  }

  /// The first run date for a schedule starting at [startDate]: weekly
  /// starts on the start date itself; monthly on the anchor day of the
  /// start month, or of the following month when it already passed.
  static DateTime firstRunDate({
    required RecurrenceFrequency frequency,
    required DateTime startDate,
    required int dayOfMonth,
  }) {
    final start = _dateOnly(startDate);
    switch (frequency) {
      case RecurrenceFrequency.weekly:
        return start;
      case RecurrenceFrequency.monthly:
        final candidate = clampToMonth(start.year, start.month, dayOfMonth);
        return candidate.isBefore(start)
            ? clampToMonth(start.year, start.month + 1, dayOfMonth)
            : candidate;
    }
  }

  /// `day` clamped into the given month (handles month overflow in
  /// [month], e.g. month 13 = January next year).
  static DateTime clampToMonth(int year, int month, int day) {
    final lastDay = DateTime(year, month + 1, 0).day;
    return DateTime(year, month, day > lastDay ? lastDay : day);
  }

  static Invoice _materialize(
    RecurringTemplate template,
    DateTime issueDate,
    String number,
    String Function() newId,
    DateTime now,
  ) {
    return Invoice(
      id: newId(),
      number: number,
      clientId: template.clientId,
      currency: template.currency,
      issueDate: issueDate,
      dueDate: DateTime(
        issueDate.year,
        issueDate.month,
        issueDate.day + template.dueInDays,
      ),
      items: [
        for (final item in template.items)
          LineItem(
            id: newId(),
            description: item.description,
            quantityMilli: item.quantityMilli,
            unitPriceMinor: item.unitPriceMinor,
          ),
      ],
      taxRateBp: template.taxRateBp,
      discountType: template.discountType,
      discountValue: template.discountValue,
      notes: template.notes,
      template: template.template,
      createdAt: now,
    );
  }

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);
}

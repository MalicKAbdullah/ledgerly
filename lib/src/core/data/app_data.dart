import 'package:flutter/foundation.dart';
import 'package:ledgerly/src/features/clients/models/client.dart';
import 'package:ledgerly/src/features/estimates/models/estimate.dart';
import 'package:ledgerly/src/features/expenses/models/expense.dart';
import 'package:ledgerly/src/features/invoices/models/invoice.dart';
import 'package:ledgerly/src/features/recurring/models/recurring_template.dart';
import 'package:ledgerly/src/features/settings/models/business_profile.dart';

/// The entire application state as one immutable snapshot. It is serialized
/// to JSON, encrypted, and written as a single file on every mutation.
///
/// Backward compatibility contract: every field added after v1.1 must be
/// optional in [AppData.fromJson] with a sensible default, so vaults (and
/// backups) written by older versions always load.
@immutable
final class AppData {
  const AppData({
    this.profile = const BusinessProfile(),
    this.clients = const <Client>[],
    this.invoices = const <Invoice>[],
    this.expenses = const <Expense>[],
    this.estimates = const <Estimate>[],
    this.recurringTemplates = const <RecurringTemplate>[],
  });

  factory AppData.fromJson(Map<String, dynamic> json) {
    return AppData(
      profile: BusinessProfile.fromJson(
        json['profile'] as Map<String, dynamic>? ?? const <String, dynamic>{},
      ),
      clients: (json['clients'] as List<dynamic>? ?? const <dynamic>[])
          .map((e) => Client.fromJson(e as Map<String, dynamic>))
          .toList(),
      invoices: (json['invoices'] as List<dynamic>? ?? const <dynamic>[])
          .map((e) => Invoice.fromJson(e as Map<String, dynamic>))
          .toList(),
      expenses: (json['expenses'] as List<dynamic>? ?? const <dynamic>[])
          .map((e) => Expense.fromJson(e as Map<String, dynamic>))
          .toList(),
      estimates: (json['estimates'] as List<dynamic>? ?? const <dynamic>[])
          .map((e) => Estimate.fromJson(e as Map<String, dynamic>))
          .toList(),
      recurringTemplates:
          (json['recurringTemplates'] as List<dynamic>? ?? const <dynamic>[])
              .map((e) => RecurringTemplate.fromJson(e as Map<String, dynamic>))
              .toList(),
    );
  }

  /// v1: profile/clients/invoices. v2 adds expenses, estimates, and
  /// recurring templates — all optional on read, so v1 files still load.
  static const int schemaVersion = 2;

  final BusinessProfile profile;
  final List<Client> clients;
  final List<Invoice> invoices;
  final List<Expense> expenses;
  final List<Estimate> estimates;
  final List<RecurringTemplate> recurringTemplates;

  Client? clientById(String id) {
    for (final client in clients) {
      if (client.id == id) return client;
    }
    return null;
  }

  Invoice? invoiceById(String id) {
    for (final invoice in invoices) {
      if (invoice.id == id) return invoice;
    }
    return null;
  }

  Expense? expenseById(String id) {
    for (final expense in expenses) {
      if (expense.id == id) return expense;
    }
    return null;
  }

  Estimate? estimateById(String id) {
    for (final estimate in estimates) {
      if (estimate.id == id) return estimate;
    }
    return null;
  }

  RecurringTemplate? recurringTemplateById(String id) {
    for (final template in recurringTemplates) {
      if (template.id == id) return template;
    }
    return null;
  }

  List<Invoice> invoicesForClient(String clientId) =>
      invoices.where((i) => i.clientId == clientId).toList();

  AppData copyWith({
    BusinessProfile? profile,
    List<Client>? clients,
    List<Invoice>? invoices,
    List<Expense>? expenses,
    List<Estimate>? estimates,
    List<RecurringTemplate>? recurringTemplates,
  }) {
    return AppData(
      profile: profile ?? this.profile,
      clients: clients ?? this.clients,
      invoices: invoices ?? this.invoices,
      expenses: expenses ?? this.expenses,
      estimates: estimates ?? this.estimates,
      recurringTemplates: recurringTemplates ?? this.recurringTemplates,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'schemaVersion': schemaVersion,
    'profile': profile.toJson(),
    'clients': clients.map((c) => c.toJson()).toList(),
    'invoices': invoices.map((i) => i.toJson()).toList(),
    'expenses': expenses.map((e) => e.toJson()).toList(),
    'estimates': estimates.map((e) => e.toJson()).toList(),
    'recurringTemplates': recurringTemplates.map((t) => t.toJson()).toList(),
  };
}

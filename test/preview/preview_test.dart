import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerly/src/features/backup/screens/backup_screen.dart';
import 'package:ledgerly/src/features/clients/screens/client_detail_screen.dart';
import 'package:ledgerly/src/features/clients/screens/clients_screen.dart';
import 'package:ledgerly/src/features/dashboard/screens/dashboard_screen.dart';
import 'package:ledgerly/src/features/estimates/screens/estimate_detail_screen.dart';
import 'package:ledgerly/src/features/estimates/screens/estimates_screen.dart';
import 'package:ledgerly/src/features/expenses/screens/expenses_screen.dart';
import 'package:ledgerly/src/features/invoices/screens/invoice_editor_screen.dart';
import 'package:ledgerly/src/features/invoices/screens/invoice_preview_screen.dart';
import 'package:ledgerly/src/features/invoices/screens/invoices_screen.dart';
import 'package:ledgerly/src/features/onboarding/onboarding_screen.dart';
import 'package:ledgerly/src/features/recurring/screens/recurring_screen.dart';
import 'package:ledgerly/src/features/settings/screens/settings_screen.dart';

import 'preview_support.dart';
import 'sample_data.dart';

/// Design-review renders of every main screen, light and dark. Run with
/// `PREVIEW=OUT_DIR flutter test test/preview`; skipped otherwise.
void main() {
  final enabled = previewOut != null;

  setUpAll(() async {
    if (enabled) await loadPreviewFonts();
  });

  final data = sampleData();

  void shot(String name, Widget Function() screen, {double height = 844}) {
    testWidgets(name, (tester) async {
      await renderScreen(tester, name, screen, data: data, height: height);
    }, skip: !enabled);
  }

  shot('dashboard', () => const DashboardScreen(), height: 1500);
  shot('invoices', () => const InvoicesScreen());
  shot(
    'invoice-detail',
    () => const InvoicePreviewScreen(invoiceId: 'part-1'),
    height: 1900,
  );
  shot(
    'invoice-editor',
    () => const InvoiceEditorScreen(invoiceId: 'sent-1'),
    height: 1500,
  );
  shot('clients', () => const ClientsScreen());
  shot('client-detail', () => const ClientDetailScreen(clientId: 'c2'));
  shot('expenses', () => const ExpensesScreen());
  shot('estimates', () => const EstimatesScreen());
  shot(
    'estimate-detail',
    () => const EstimateDetailScreen(estimateId: 'est1'),
    height: 1300,
  );
  shot('recurring', () => const RecurringScreen());
  shot('settings', () => const SettingsScreen(), height: 2600);
  shot('backup', () => const BackupScreen());
  shot('onboarding', () => const OnboardingScreen());
}

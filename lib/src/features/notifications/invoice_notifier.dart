import 'package:core_notify/core_notify.dart';
import 'package:core_storage/core_storage.dart';
import 'package:ledgerly/src/core/data/app_data.dart';
import 'package:ledgerly/src/features/invoices/models/invoice.dart';

/// On-device invoice reminders: when you open Ledgerly, a heads-up if any sent
/// invoices are overdue or falling due within two days. Deduped to at most one
/// notification per day. Nothing leaves the device.
class InvoiceNotifier {
  InvoiceNotifier({required INotify notify, required ISecureStorage storage})
    : _notify = notify,
      _storage = storage;

  final INotify _notify;
  final ISecureStorage _storage;

  static const List<NotifyChannel> channels = [
    NotifyChannel(
      id: 'invoice_reminders',
      name: 'Invoice reminders',
      description: 'Overdue and due-soon invoices',
      importance: NotifyImportance.high,
    ),
  ];

  static const String _lastShownKey = 'ledgerly_invoice_reminder_shown';

  Future<void> checkOnOpen(AppData data, DateTime now) async {
    if (!await _notify.isPermitted()) return;

    var overdue = 0;
    var dueSoon = 0;
    final today = DateTime(now.year, now.month, now.day);
    for (final inv in data.invoices) {
      if (inv.status != InvoiceStatus.sent) continue;
      if (inv.isOverdue(now)) {
        overdue++;
      } else {
        final due = DateTime(
          inv.dueDate.year,
          inv.dueDate.month,
          inv.dueDate.day,
        );
        final days = due.difference(today).inDays;
        if (days >= 0 && days <= 2) dueSoon++;
      }
    }
    if (overdue == 0 && dueSoon == 0) return;

    // At most one reminder per calendar day.
    final todayKey = '${now.year}-${now.month}-${now.day}';
    if (await _storage.read(key: _lastShownKey) == todayKey) return;

    final parts = <String>[
      if (overdue > 0) '$overdue overdue',
      if (dueSoon > 0) '$dueSoon due soon',
    ];
    await _notify.show(
      NotifyRequest(
        id: 800001,
        channelId: 'invoice_reminders',
        title: overdue > 0 ? 'Invoices need attention' : 'Invoices due soon',
        body: '${parts.join(' · ')}. Tap to review and send a reminder.',
        payload: 'invoices',
      ),
    );
    await _storage.write(key: _lastShownKey, value: todayKey);
  }
}

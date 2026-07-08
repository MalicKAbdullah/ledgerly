import 'package:ledgerly/src/core/formats.dart';
import 'package:ledgerly/src/features/clients/models/client.dart';
import 'package:ledgerly/src/features/invoices/models/invoice.dart';
import 'package:ledgerly/src/features/invoices/services/payment_math.dart';
import 'package:ledgerly/src/features/settings/models/business_profile.dart';

/// Builds the friendly payment-reminder message shared from the invoice
/// detail screen. Pure string work — unit tested.
abstract final class ReminderService {
  static String buildReminderText({
    required BusinessProfile profile,
    required Client client,
    required Invoice invoice,
    required DateTime now,
  }) {
    final balance = PaymentMath.balanceDue(invoice);
    final due = Formats.date(invoice.dueDate);
    final overdue = invoice.isOverdue(now);

    final buffer = StringBuffer()
      ..write('Hi ${client.name},\n\n')
      ..write(
        overdue
            ? 'Just a friendly reminder that invoice ${invoice.number} '
                  'for ${balance.format()} was due on $due.'
            : 'Just a friendly reminder that invoice ${invoice.number} '
                  'for ${balance.format()} is due on $due.',
      )
      ..write('\n\nThank you!');
    if (profile.displayName.isNotEmpty) {
      buffer.write('\n${profile.displayName}');
    }
    return buffer.toString();
  }
}

import 'package:ledgerly/src/core/data/app_data.dart';
import 'package:ledgerly/src/features/estimates/models/estimate.dart';
import 'package:ledgerly/src/features/expenses/models/expense.dart';
import 'package:ledgerly/src/features/invoices/models/invoice.dart';
import 'package:ledgerly/src/features/recurring/models/recurring_template.dart';
import 'package:ledgerly/src/features/settings/models/business_profile.dart';

import '../helpers/fakes.dart';

/// A believable freelancer's books, relative to now so the dashboard's
/// month buckets are populated.
AppData sampleData() {
  final now = DateTime.now();
  DateTime ago(int days) => now.subtract(Duration(days: days));
  DateTime ahead(int days) => now.add(Duration(days: days));

  LineItem item(String id, String d, int price, {int qty = 1000}) => LineItem(
    id: id,
    description: d,
    quantityMilli: qty,
    unitPriceMinor: price,
  );

  final clients = [
    makeClient(
      id: 'c1',
      name: 'Ada Lovelace',
      company: 'Analytical Engines Ltd',
    ),
    makeClient(id: 'c2', name: 'Grace Hopper', company: 'Compiler Co.'),
    makeClient(id: 'c3', name: 'Linus Torvalds', company: ''),
    makeClient(id: 'c4', name: 'Margaret Hamilton', company: 'Apollo Software'),
  ];

  final invoices = <Invoice>[
    for (var m = 1; m <= 5; m++)
      makeInvoice(
        id: 'paid-$m',
        number: 'INV-2026-00${10 - m}',
        clientId: clients[m % 4].id,
        status: InvoiceStatus.paid,
        issueDate: DateTime(now.year, now.month - m, 5),
        dueDate: DateTime(now.year, now.month - m, 19),
        paidAt: DateTime(now.year, now.month - m, 12),
        createdAt: DateTime(now.year, now.month - m, 5),
        items: [item('p$m', 'Retainer', 120000 + m * 31000)],
      ),
    makeInvoice(
      id: 'paid-now',
      number: 'INV-2026-0011',
      clientId: 'c2',
      status: InvoiceStatus.paid,
      paidAt: ago(2),
      createdAt: ago(9),
      issueDate: ago(9),
      dueDate: ahead(5),
      items: [item('n1', 'Brand identity', 240000)],
    ),
    makeInvoice(
      id: 'sent-1',
      number: 'INV-2026-0012',
      clientId: 'c1',
      status: InvoiceStatus.sent,
      createdAt: ago(6),
      issueDate: ago(6),
      dueDate: ahead(8),
      items: [
        item('s1', 'Design sprint', 180000),
        item('s2', 'Workshop', 45000),
      ],
    ),
    makeInvoice(
      id: 'over-1',
      number: 'INV-2026-0009',
      clientId: 'c3',
      status: InvoiceStatus.sent,
      createdAt: ago(40),
      issueDate: ago(40),
      dueDate: ago(12),
      items: [item('o1', 'Consulting', 96000, qty: 8000)],
    ),
    makeInvoice(
      id: 'part-1',
      number: 'INV-2026-0013',
      clientId: 'c4',
      status: InvoiceStatus.sent,
      createdAt: ago(3),
      issueDate: ago(3),
      dueDate: ahead(11),
      items: [item('q1', 'Mobile audit', 320000)],
      payments: [makePayment(id: 'pp1', amountMinor: 100000, date: ago(1))],
    ),
    makeInvoice(
      id: 'draft-1',
      number: 'INV-2026-0014',
      clientId: 'c2',
      createdAt: ago(1),
      issueDate: ago(1),
      dueDate: ahead(14),
      items: [item('d1', 'Maintenance', 60000)],
    ),
  ];

  final expenses = [
    for (var m = 0; m < 4; m++)
      Expense(
        id: 'e$m',
        date: DateTime(now.year, now.month - m, 8),
        category: ExpenseCategory.values[m % 5],
        description: [
          'Figma seats',
          'Train to Leeds',
          'Co-working',
          'Stripe fees',
        ][m],
        amountMinor: 18000 + m * 9500,
        currency: 'USD',
        createdAt: DateTime(now.year, now.month - m, 8),
      ),
  ];

  final estimates = [
    Estimate(
      id: 'est1',
      number: 'EST-2026-0003',
      clientId: 'c1',
      currency: 'USD',
      issueDate: ago(4),
      validUntil: ahead(26),
      items: [item('x1', 'Website redesign', 480000)],
      status: EstimateStatus.sent,
      createdAt: ago(4),
    ),
    Estimate(
      id: 'est2',
      number: 'EST-2026-0002',
      clientId: 'c4',
      currency: 'USD',
      issueDate: ago(20),
      validUntil: ahead(10),
      items: [item('x2', 'App store assets', 90000)],
      status: EstimateStatus.accepted,
      createdAt: ago(20),
    ),
  ];

  final recurring = [
    RecurringTemplate(
      id: 'r1',
      clientId: 'c2',
      currency: 'USD',
      items: [item('r1', 'Monthly retainer', 150000)],
      frequency: RecurrenceFrequency.monthly,
      startDate: ago(120),
      nextRunDate: ahead(9),
      createdAt: ago(120),
    ),
  ];

  return AppData(
    profile: const BusinessProfile(
      name: 'Sara Khan',
      businessName: 'Khan Studio',
      email: 'sara@khan.studio',
      address: '4 Park Lane, Leeds',
      defaultCurrency: 'USD',
    ),
    clients: clients,
    invoices: invoices,
    expenses: expenses,
    estimates: estimates,
    recurringTemplates: recurring,
  );
}

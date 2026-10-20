import 'package:core_theme/core_theme.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ledgerly/src/core/data/app_data.dart';
import 'package:ledgerly/src/core/formats.dart';
import 'package:ledgerly/src/core/money/money.dart';
import 'package:ledgerly/src/core/providers.dart';
import 'package:ledgerly/src/core/widgets/amount_text.dart';
import 'package:ledgerly/src/core/widgets/async_view.dart';
import 'package:ledgerly/src/features/recurring/models/recurring_template.dart';

/// Manage recurring schedules: pause/resume, edit, delete, next run.
final class RecurringScreen extends ConsumerWidget {
  const RecurringScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(appDataProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Recurring invoices')),
      floatingActionButton: FloatingActionButton(
        key: const Key('new-recurring'),
        onPressed: () => context.go('/invoices/recurring/new'),
        child: const Icon(Icons.add),
      ),
      body: AsyncView<AppData>(
        value: asyncData,
        builder: (data) {
          final templates = [...data.recurringTemplates]
            ..sort((a, b) => a.nextRunDate.compareTo(b.nextRunDate));

          if (templates.isEmpty) {
            return const AppEmptyState(
              icon: Icons.autorenew,
              title: 'No recurring schedules',
              message:
                  'Open an invoice and choose "Make recurring", or tap + to '
                  'build one from scratch. Due invoices are generated '
                  'automatically when you open the app.',
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.gutter,
              AppSpacing.md,
              AppSpacing.gutter,
              96,
            ),
            children: [
              RowGroup(
                children: [
                  for (final template in templates)
                    _TemplateTile(
                      template: template,
                      clientName:
                          data.clientById(template.clientId)?.name ?? 'Unknown',
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

final class _TemplateTile extends ConsumerWidget {
  const _TemplateTile({required this.template, required this.clientName});

  final RecurringTemplate template;
  final String clientName;

  Money _perRunTotal() {
    var subtotal = Money.zero(template.currency);
    for (final item in template.items) {
      subtotal += item.total(template.currency);
    }
    return subtotal;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(appDataProvider.notifier);
    final end = template.endDate;
    final ended = end != null && template.nextRunDate.isAfter(end);
    final c = SuiteColors.of(context);
    final statusLine = !template.active
        ? 'Paused'
        : ended
        ? 'Ended ${Formats.dateShort(end)}'
        : 'Next ${Formats.dateShort(template.nextRunDate)}';

    // Pause/resume lives in the menu so the row keeps room for the client,
    // schedule, amount and next run without truncating.
    return AppListRow(
      onTap: () => context.go('/invoices/recurring/${template.id}/edit'),
      leading: IconBadge(
        icon: template.active ? Icons.autorenew : Icons.pause_rounded,
        color: template.active ? c.accent : c.textTertiary,
      ),
      title: clientName,
      subtitle: template.describeSchedule(),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              AmountText(
                _perRunTotal(),
                style: AppTextStyles.number,
                alignment: AlignmentDirectional.centerEnd,
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                statusLine,
                style: AppTextStyles.caption.copyWith(
                  color: template.active ? c.textSecondary : c.warning,
                ),
              ),
            ],
          ),
          PopupMenuButton<String>(
            key: Key('recurring-menu-${template.id}'),
            icon: const Icon(Icons.more_vert, size: 20),
            onSelected: (action) async {
              switch (action) {
                case 'toggle':
                  await notifier.setRecurringActive(
                    template.id,
                    !template.active,
                  );
                case 'edit':
                  context.go('/invoices/recurring/${template.id}/edit');
                case 'delete':
                  final messenger = ScaffoldMessenger.of(context);
                  await notifier.deleteRecurringTemplate(template.id);
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Recurring schedule deleted')),
                  );
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'toggle',
                child: Text(template.active ? 'Pause' : 'Resume'),
              ),
              const PopupMenuItem(value: 'edit', child: Text('Edit')),
              const PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
    );
  }
}

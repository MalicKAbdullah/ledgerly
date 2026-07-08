import 'package:core_theme/core_theme.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ledgerly/src/core/data/app_data.dart';
import 'package:ledgerly/src/core/formats.dart';
import 'package:ledgerly/src/core/money/money.dart';
import 'package:ledgerly/src/core/providers.dart';
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
            return const VaultEmptyState(
              icon: Icons.autorenew,
              message:
                  'No recurring schedules yet.\nOpen an invoice and '
                  'choose "Make recurring", or tap + to build one from '
                  'scratch. Due invoices are generated automatically when '
                  'you open the app.',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              96,
            ),
            itemCount: templates.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) => _TemplateTile(
              template: templates[index],
              clientName:
                  data.clientById(templates[index].clientId)?.name ?? 'Unknown',
            ),
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
    final theme = Theme.of(context);
    final notifier = ref.read(appDataProvider.notifier);
    final end = template.endDate;
    final ended = end != null && template.nextRunDate.isAfter(end);
    final statusLine = !template.active
        ? 'Paused'
        : ended
        ? 'Ended ${Formats.date(end)}'
        : 'Next run ${Formats.date(template.nextRunDate)}';

    return VaultCard(
      onTap: () => context.go('/invoices/recurring/${template.id}/edit'),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(AppSpacing.sm),
            ),
            child: Icon(
              Icons.autorenew,
              size: 18,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$clientName · ${_perRunTotal().format()} '
                  '(before tax/discount)',
                  style: theme.textTheme.titleSmall,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${template.describeSchedule()} · $statusLine',
                  style: theme.textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Switch(
            key: Key('recurring-active-${template.id}'),
            value: template.active,
            onChanged: (active) =>
                notifier.setRecurringActive(template.id, active),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, size: 20),
            onSelected: (action) async {
              switch (action) {
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
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
    );
  }
}

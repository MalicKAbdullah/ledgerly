import 'package:core_theme/core_theme.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ledgerly/src/core/data/app_data.dart';
import 'package:ledgerly/src/core/providers.dart';
import 'package:ledgerly/src/core/widgets/async_view.dart';

final class ClientsScreen extends ConsumerStatefulWidget {
  const ClientsScreen({super.key});

  @override
  ConsumerState<ClientsScreen> createState() => _ClientsScreenState();
}

final class _ClientsScreenState extends ConsumerState<ClientsScreen> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncData = ref.watch(appDataProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Clients')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/clients/new'),
        child: const Icon(Icons.person_add_alt),
      ),
      body: AsyncView<AppData>(
        value: asyncData,
        builder: (data) {
          final query = _search.text.trim();
          final clients =
              data.clients
                  .where((c) => query.isEmpty || c.matches(query))
                  .toList()
                ..sort(
                  (a, b) =>
                      a.name.toLowerCase().compareTo(b.name.toLowerCase()),
                );

          if (data.clients.isEmpty) {
            return const AppEmptyState(
              icon: Icons.people_outline,
              title: 'No clients yet',
              message: 'Add the people and companies you bill.',
            );
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.gutter,
                  AppSpacing.sm,
                  AppSpacing.gutter,
                  AppSpacing.sm,
                ),
                child: AppSearchField(
                  controller: _search,
                  hint: 'Search clients',
                  onChanged: (_) => setState(() {}),
                ),
              ),
              Expanded(
                child: clients.isEmpty
                    ? const AppEmptyState(
                        icon: Icons.search_off,
                        title: 'No matches',
                        message: 'No clients match your search.',
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.gutter,
                          AppSpacing.xs,
                          AppSpacing.gutter,
                          96,
                        ),
                        children: [
                          RowGroup(
                            children: [
                              for (final client in clients)
                                AppListRow(
                                  onTap: () =>
                                      context.go('/clients/${client.id}'),
                                  leading: IconBadge(
                                    monogram: client.name.isEmpty
                                        ? '?'
                                        : client.name[0].toUpperCase(),
                                    color: SuiteColors.of(context).accent,
                                  ),
                                  title: client.name,
                                  subtitle: client.company.isEmpty
                                      ? null
                                      : client.company,
                                  trailingSubtitle: _invoiceCount(
                                    data,
                                    client.id,
                                  ),
                                  showChevron: true,
                                ),
                            ],
                          ),
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _invoiceCount(AppData data, String clientId) {
    final count = data.invoicesForClient(clientId).length;
    return count == 1 ? '1 invoice' : '$count invoices';
  }
}

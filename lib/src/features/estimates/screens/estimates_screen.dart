import 'package:core_theme/core_theme.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ledgerly/src/core/data/app_data.dart';
import 'package:ledgerly/src/core/providers.dart';
import 'package:ledgerly/src/core/widgets/async_view.dart';
import 'package:ledgerly/src/features/estimates/models/estimate.dart';
import 'package:ledgerly/src/features/estimates/widgets/estimate_widgets.dart';

enum _EstimateFilter { all, draft, sent, accepted, declined, expired }

/// All estimates with status filters. Estimates convert to invoices from
/// their detail screen.
final class EstimatesScreen extends ConsumerStatefulWidget {
  const EstimatesScreen({super.key});

  @override
  ConsumerState<EstimatesScreen> createState() => _EstimatesScreenState();
}

final class _EstimatesScreenState extends ConsumerState<EstimatesScreen> {
  _EstimateFilter _filter = _EstimateFilter.all;

  @override
  Widget build(BuildContext context) {
    final asyncData = ref.watch(appDataProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Estimates')),
      floatingActionButton: FloatingActionButton(
        key: const Key('new-estimate'),
        onPressed: () => context.go('/invoices/estimates/new'),
        child: const Icon(Icons.add),
      ),
      body: AsyncView<AppData>(
        value: asyncData,
        builder: (data) {
          final now = DateTime.now();
          final estimates = data.estimates.where((e) {
            return switch (_filter) {
              _EstimateFilter.all => true,
              _EstimateFilter.draft =>
                e.status == EstimateStatus.draft && !e.isExpired(now),
              _EstimateFilter.sent =>
                e.status == EstimateStatus.sent && !e.isExpired(now),
              _EstimateFilter.accepted => e.status == EstimateStatus.accepted,
              _EstimateFilter.declined => e.status == EstimateStatus.declined,
              _EstimateFilter.expired => e.isExpired(now),
            };
          }).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));

          return Column(
            children: [
              SizedBox(
                height: 48,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  children: [
                    for (final filter in _EstimateFilter.values)
                      Padding(
                        padding: const EdgeInsets.only(right: AppSpacing.sm),
                        child: FilterChip(
                          label: Text(_filterLabel(filter)),
                          selected: _filter == filter,
                          onSelected: (_) => setState(() => _filter = filter),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: estimates.isEmpty
                    ? VaultEmptyState(
                        icon: Icons.request_quote_outlined,
                        message: data.estimates.isEmpty
                            ? 'No estimates yet.\nTap + to quote your next '
                                  'project — accepted estimates convert to '
                                  'invoices in one tap.'
                            : 'No ${_filterLabel(_filter).toLowerCase()} '
                                  'estimates.',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.md,
                          AppSpacing.sm,
                          AppSpacing.md,
                          96,
                        ),
                        itemCount: estimates.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: AppSpacing.sm),
                        itemBuilder: (context, index) {
                          final estimate = estimates[index];
                          return EstimateTile(
                            estimate: estimate,
                            clientName:
                                data.clientById(estimate.clientId)?.name ??
                                'Unknown',
                            onTap: () => context.go(
                              '/invoices/estimates/${estimate.id}',
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _filterLabel(_EstimateFilter filter) => switch (filter) {
    _EstimateFilter.all => 'All',
    _EstimateFilter.draft => 'Draft',
    _EstimateFilter.sent => 'Sent',
    _EstimateFilter.accepted => 'Accepted',
    _EstimateFilter.declined => 'Declined',
    _EstimateFilter.expired => 'Expired',
  };
}

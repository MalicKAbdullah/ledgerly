import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ledgerly/src/features/backup/screens/backup_screen.dart';
import 'package:ledgerly/src/features/clients/screens/client_detail_screen.dart';
import 'package:ledgerly/src/features/clients/screens/client_editor_screen.dart';
import 'package:ledgerly/src/features/clients/screens/clients_screen.dart';
import 'package:ledgerly/src/features/dashboard/screens/dashboard_screen.dart';
import 'package:ledgerly/src/features/estimates/screens/estimate_detail_screen.dart';
import 'package:ledgerly/src/features/estimates/screens/estimate_editor_screen.dart';
import 'package:ledgerly/src/features/estimates/screens/estimates_screen.dart';
import 'package:ledgerly/src/features/expenses/screens/expenses_screen.dart';
import 'package:ledgerly/src/features/invoices/screens/invoice_editor_screen.dart';
import 'package:ledgerly/src/features/invoices/screens/invoice_preview_screen.dart';
import 'package:ledgerly/src/features/invoices/screens/invoices_screen.dart';
import 'package:ledgerly/src/features/recurring/screens/recurring_editor_screen.dart';
import 'package:ledgerly/src/features/recurring/screens/recurring_screen.dart';
import 'package:ledgerly/src/features/settings/screens/settings_screen.dart';
import 'package:ledgerly/src/features/shell/home_shell.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/dashboard',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => HomeShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/dashboard',
                builder: (context, state) => const DashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/invoices',
                builder: (context, state) => const InvoicesScreen(),
                routes: [
                  GoRoute(
                    path: 'estimates',
                    builder: (context, state) => const EstimatesScreen(),
                    routes: [
                      GoRoute(
                        path: 'new',
                        parentNavigatorKey: _rootNavigatorKey,
                        builder: (context, state) => EstimateEditorScreen(
                          clientId: state.uri.queryParameters['clientId'],
                        ),
                      ),
                      GoRoute(
                        path: ':estimateId',
                        builder: (context, state) => EstimateDetailScreen(
                          estimateId: state.pathParameters['estimateId']!,
                        ),
                        routes: [
                          GoRoute(
                            path: 'edit',
                            parentNavigatorKey: _rootNavigatorKey,
                            builder: (context, state) => EstimateEditorScreen(
                              estimateId: state.pathParameters['estimateId'],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'recurring',
                    builder: (context, state) => const RecurringScreen(),
                    routes: [
                      GoRoute(
                        path: 'new',
                        parentNavigatorKey: _rootNavigatorKey,
                        builder: (context, state) => RecurringEditorScreen(
                          fromInvoiceId:
                              state.uri.queryParameters['fromInvoice'],
                        ),
                      ),
                      GoRoute(
                        path: ':templateId/edit',
                        parentNavigatorKey: _rootNavigatorKey,
                        builder: (context, state) => RecurringEditorScreen(
                          templateId: state.pathParameters['templateId'],
                        ),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'new',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) => InvoiceEditorScreen(
                      clientId: state.uri.queryParameters['clientId'],
                    ),
                  ),
                  GoRoute(
                    path: ':id',
                    builder: (context, state) => InvoicePreviewScreen(
                      invoiceId: state.pathParameters['id']!,
                    ),
                    routes: [
                      GoRoute(
                        path: 'edit',
                        parentNavigatorKey: _rootNavigatorKey,
                        builder: (context, state) => InvoiceEditorScreen(
                          invoiceId: state.pathParameters['id'],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/expenses',
                builder: (context, state) => const ExpensesScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/clients',
                builder: (context, state) => const ClientsScreen(),
                routes: [
                  GoRoute(
                    path: 'new',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) => const ClientEditorScreen(),
                  ),
                  GoRoute(
                    path: ':id',
                    builder: (context, state) => ClientDetailScreen(
                      clientId: state.pathParameters['id']!,
                    ),
                    routes: [
                      GoRoute(
                        path: 'edit',
                        parentNavigatorKey: _rootNavigatorKey,
                        builder: (context, state) => ClientEditorScreen(
                          clientId: state.pathParameters['id'],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                builder: (context, state) => const SettingsScreen(),
                routes: [
                  GoRoute(
                    path: 'backup',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) => const BackupScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

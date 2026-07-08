import 'package:core_theme/core_theme.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ledgerly/src/core/providers.dart';
import 'package:ledgerly/src/features/clients/models/client.dart';

/// Create ([clientId] null) or edit an existing client.
final class ClientEditorScreen extends ConsumerStatefulWidget {
  const ClientEditorScreen({this.clientId, super.key});

  final String? clientId;

  @override
  ConsumerState<ClientEditorScreen> createState() => _ClientEditorScreenState();
}

final class _ClientEditorScreenState extends ConsumerState<ClientEditorScreen> {
  final _name = TextEditingController();
  final _company = TextEditingController();
  final _email = TextEditingController();
  final _address = TextEditingController();
  final _notes = TextEditingController();

  String? _nameError;
  bool _initialized = false;

  @override
  void dispose() {
    _name.dispose();
    _company.dispose();
    _email.dispose();
    _address.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _initFrom(Client? existing) {
    if (_initialized || existing == null) {
      _initialized = true;
      return;
    }
    _initialized = true;
    _name.text = existing.name;
    _company.text = existing.company;
    _email.text = existing.email;
    _address.text = existing.address;
    _notes.text = existing.notes;
  }

  Future<void> _save(Client? existing) async {
    final name = _name.text.trim();
    setState(() => _nameError = name.isEmpty ? 'Name is required' : null);
    if (_nameError != null) return;

    final notifier = ref.read(appDataProvider.notifier);
    if (existing == null) {
      await notifier.createClient(
        (id) => Client(
          id: id,
          name: name,
          company: _company.text.trim(),
          email: _email.text.trim(),
          address: _address.text.trim(),
          notes: _notes.text.trim(),
          createdAt: DateTime.now(),
        ),
      );
    } else {
      await notifier.updateClient(
        existing.copyWith(
          name: name,
          company: _company.text.trim(),
          email: _email.text.trim(),
          address: _address.text.trim(),
          notes: _notes.text.trim(),
        ),
      );
    }
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/clients');
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(appDataProvider).valueOrNull;
    final existing = widget.clientId == null
        ? null
        : data?.clientById(widget.clientId!);
    _initFrom(existing);

    return Scaffold(
      appBar: AppBar(
        title: Text(existing == null ? 'New Client' : 'Edit Client'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          VaultTextField(
            label: 'Name',
            controller: _name,
            hint: 'Jane Doe',
            errorText: _nameError,
            autofocus: existing == null,
          ),
          const SizedBox(height: AppSpacing.md),
          VaultTextField(
            label: 'Company',
            controller: _company,
            hint: 'Acme Inc.',
          ),
          const SizedBox(height: AppSpacing.md),
          VaultTextField(
            label: 'Email',
            controller: _email,
            hint: 'jane@acme.com',
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: AppSpacing.md),
          VaultTextField(
            label: 'Address',
            controller: _address,
            hint: '123 Main St, Springfield',
          ),
          const SizedBox(height: AppSpacing.md),
          VaultTextField(
            label: 'Notes',
            controller: _notes,
            hint: 'Prefers invoices at month end',
          ),
          const SizedBox(height: AppSpacing.lg),
          VaultButton(
            label: existing == null ? 'Add Client' : 'Save Changes',
            onPressed: () => _save(existing),
          ),
        ],
      ),
    );
  }
}

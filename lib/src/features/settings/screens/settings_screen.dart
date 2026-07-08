import 'package:core_theme/core_theme.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ledgerly/src/core/app_info.dart';
import 'package:ledgerly/src/core/money/money.dart';
import 'package:ledgerly/src/core/providers.dart';
import 'package:ledgerly/src/features/invoices/models/invoice_template.dart';
import 'package:ledgerly/src/features/settings/models/business_profile.dart';
import 'package:ledgerly/src/features/settings/widgets/logo_section.dart';
import 'package:ledgerly/src/features/settings/widgets/security_section.dart';

final class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

final class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _name = TextEditingController();
  final _businessName = TextEditingController();
  final _address = TextEditingController();
  final _email = TextEditingController();
  final _taxId = TextEditingController();
  final _taxRate = TextEditingController();
  final _prefix = TextEditingController();

  String _currency = 'USD';
  String? _taxRateError;
  bool _initialized = false;

  @override
  void dispose() {
    _name.dispose();
    _businessName.dispose();
    _address.dispose();
    _email.dispose();
    _taxId.dispose();
    _taxRate.dispose();
    _prefix.dispose();
    super.dispose();
  }

  void _initFrom(BusinessProfile profile) {
    if (_initialized) return;
    _initialized = true;
    _name.text = profile.name;
    _businessName.text = profile.businessName;
    _address.text = profile.address;
    _email.text = profile.email;
    _taxId.text = profile.taxId;
    _taxRate.text = formatBasisPoints(profile.defaultTaxRateBp);
    _prefix.text = profile.invoicePrefix;
    _currency = profile.defaultCurrency;
  }

  BusinessProfile get _storedProfile =>
      ref.read(appDataProvider).requireValue.profile;

  /// Instant-apply settings (logo, template, footer toggle) save straight
  /// away; the text fields below still use the explicit Save button.
  Future<void> _apply(BusinessProfile profile) =>
      ref.read(appDataProvider.notifier).saveProfile(profile);

  Future<void> _save() async {
    final taxBp = tryParseBasisPoints(_taxRate.text);
    setState(() {
      _taxRateError = (taxBp == null || taxBp < 0)
          ? 'Enter a rate like 7.5'
          : null;
    });
    if (_taxRateError != null) return;

    final prefix = _prefix.text.trim();
    await _apply(
      _storedProfile.copyWith(
        name: _name.text.trim(),
        businessName: _businessName.text.trim(),
        address: _address.text.trim(),
        email: _email.text.trim(),
        taxId: _taxId.text.trim(),
        defaultCurrency: _currency,
        defaultTaxRateBp: taxBp!,
        invoicePrefix: prefix.isEmpty ? 'INV' : prefix,
      ),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Business profile saved')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final data = ref.watch(appDataProvider).valueOrNull;
    if (data == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    _initFrom(data.profile);
    final profile = data.profile;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Text('Business profile', style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Shown on every invoice you send.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.md),
          LogoSection(
            profile: profile,
            onLogoChanged: (logo) =>
                _apply(_storedProfile.copyWith(logoBase64: logo)),
          ),
          const SizedBox(height: AppSpacing.md),
          VaultTextField(
            label: 'Your name',
            controller: _name,
            hint: 'Jane Doe',
          ),
          const SizedBox(height: AppSpacing.md),
          VaultTextField(
            label: 'Business name',
            controller: _businessName,
            hint: 'Jane Doe Studio',
          ),
          const SizedBox(height: AppSpacing.md),
          VaultTextField(
            label: 'Address',
            controller: _address,
            hint: '123 Main St, Springfield',
          ),
          const SizedBox(height: AppSpacing.md),
          VaultTextField(
            label: 'Email',
            controller: _email,
            hint: 'jane@studio.dev',
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: AppSpacing.md),
          VaultTextField(
            label: 'Tax ID',
            controller: _taxId,
            hint: 'e.g. VAT / EIN number',
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Invoice defaults', style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.md),
          Text('Default currency', style: AppTextStyles.label),
          const SizedBox(height: AppSpacing.sm),
          DropdownButtonFormField<String>(
            key: const Key('default-currency'),
            initialValue: _currency,
            items: [
              for (final code in {..._orderedCurrencies()})
                DropdownMenuItem(
                  value: code,
                  child: Text('$code (${Currencies.symbol(code)})'),
                ),
            ],
            onChanged: (code) => setState(() => _currency = code ?? _currency),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: VaultTextField(
                  label: 'Default tax rate (%)',
                  controller: _taxRate,
                  hint: '7.5',
                  errorText: _taxRateError,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: VaultTextField(
                  label: 'Invoice prefix',
                  controller: _prefix,
                  hint: 'INV',
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          VaultButton(label: 'Save Settings', onPressed: _save),
          const SizedBox(height: AppSpacing.lg),
          Text('Invoice PDFs', style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.md),
          Text('Default template', style: AppTextStyles.label),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<InvoiceTemplateId>(
              key: const Key('default-template'),
              segments: [
                for (final template in InvoiceTemplateId.values)
                  ButtonSegment(value: template, label: Text(template.label)),
              ],
              selected: {profile.defaultTemplate},
              onSelectionChanged: (selection) => _apply(
                _storedProfile.copyWith(defaultTemplate: selection.first),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${profile.defaultTemplate.description}. New invoices start with '
            'this look; you can switch it per invoice.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          SwitchListTile(
            key: const Key('pdf-footer-toggle'),
            contentPadding: EdgeInsets.zero,
            title: Text(
              '"Generated with Ledgerly" footer',
              style: theme.textTheme.titleSmall,
            ),
            subtitle: Text(
              'A small credit line at the bottom of each PDF.',
              style: theme.textTheme.bodySmall,
            ),
            value: profile.showPdfFooter,
            onChanged: (value) =>
                _apply(_storedProfile.copyWith(showPdfFooter: value)),
          ),
          const SizedBox(height: AppSpacing.lg),
          const SecuritySection(),
          const SizedBox(height: AppSpacing.lg),
          Text('Backup', style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.md),
          VaultCard(
            child: ListTile(
              key: const Key('backup-tile'),
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(AppSpacing.sm),
                ),
                child: Icon(
                  Icons.save_alt,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
              ),
              title: Text(
                'Backup & restore',
                style: theme.textTheme.titleSmall,
              ),
              subtitle: Text(
                'Encrypted .lybackup file — export or import your whole '
                'ledger.',
                style: theme.textTheme.bodySmall,
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/settings/backup'),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('About', style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.md),
          VaultCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(AppSpacing.sm),
                      ),
                      child: Icon(
                        Icons.receipt_long,
                        size: 18,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text('Ledgerly', style: theme.textTheme.titleSmall),
                    const Spacer(),
                    Text(
                      'Version ${AppInfo.version}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.lock_outline,
                      size: 18,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        AppInfo.privacyBlurb,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  List<String> _orderedCurrencies() => [
    ...Currencies.supported,
    if (!Currencies.supported.contains(_currency)) _currency,
  ];
}

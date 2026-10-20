import 'package:core_backup/core_backup.dart';
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
    final data = ref.watch(appDataProvider).valueOrNull;
    if (data == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    _initFrom(data.profile);
    final profile = data.profile;

    final c = SuiteColors.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.gutter,
          0,
          AppSpacing.gutter,
          AppSpacing.xl,
        ),
        children: [
          const SectionHeader(
            title: 'Business profile',
            subtitle: 'Shown on every invoice you send.',
          ),
          LogoSection(
            profile: profile,
            onLogoChanged: (logo) =>
                _apply(_storedProfile.copyWith(logoBase64: logo)),
          ),
          const SizedBox(height: AppSpacing.smd),
          AppTextField(label: 'Your name', controller: _name, hint: 'Jane Doe'),
          const SizedBox(height: AppSpacing.smd),
          AppTextField(
            label: 'Business name',
            controller: _businessName,
            hint: 'Jane Doe Studio',
          ),
          const SizedBox(height: AppSpacing.smd),
          AppTextField(
            label: 'Address',
            controller: _address,
            hint: '123 Main St, Springfield',
          ),
          const SizedBox(height: AppSpacing.smd),
          AppTextField(
            label: 'Email',
            controller: _email,
            hint: 'jane@studio.dev',
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: AppSpacing.smd),
          AppTextField(
            label: 'Tax ID',
            controller: _taxId,
            hint: 'e.g. VAT / EIN number',
          ),
          const SizedBox(height: AppSpacing.lg),
          const SectionHeader(title: 'Invoice defaults'),
          DropdownButtonFormField<String>(
            key: const Key('default-currency'),
            initialValue: _currency,
            decoration: const InputDecoration(labelText: 'Default currency'),
            items: [
              for (final code in {..._orderedCurrencies()})
                DropdownMenuItem(
                  value: code,
                  child: Text('$code (${Currencies.symbol(code)})'),
                ),
            ],
            onChanged: (code) => setState(() => _currency = code ?? _currency),
          ),
          const SizedBox(height: AppSpacing.smd),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AppTextField(
                  label: 'Default tax rate (%)',
                  controller: _taxRate,
                  hint: '7.5',
                  errorText: _taxRateError,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.smd),
              Expanded(
                child: AppTextField(
                  label: 'Invoice prefix',
                  controller: _prefix,
                  hint: 'INV',
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          VaultButton(label: 'Save Settings', onPressed: _save),
          const SizedBox(height: AppSpacing.lg),
          const SectionHeader(title: 'Invoice PDFs'),
          AppSegmentedControl<InvoiceTemplateId>(
            key: const Key('default-template'),
            segments: [
              for (final template in InvoiceTemplateId.values)
                AppSegment(value: template, label: template.label),
            ],
            selected: profile.defaultTemplate,
            onChanged: (template) =>
                _apply(_storedProfile.copyWith(defaultTemplate: template)),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${profile.defaultTemplate.description}. New invoices start with '
            'this look; you can switch it per invoice.',
            style: AppTextStyles.bodySmall.copyWith(color: c.textSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          RowGroup(
            children: [
              SettingsTile(
                key: const Key('pdf-footer-toggle'),
                icon: Icons.short_text,
                title: 'PDF footer',
                subtitle: '"Generated with Ledgerly" credit line',
                trailing: Switch(
                  value: profile.showPdfFooter,
                  onChanged: (value) =>
                      _apply(_storedProfile.copyWith(showPdfFooter: value)),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          const SecuritySection(),
          const SizedBox(height: AppSpacing.lg),
          const SectionHeader(title: 'Updates'),
          const _UpdateCheckTile(),
          const SizedBox(height: AppSpacing.lg),
          const SectionHeader(title: 'Backup'),
          RowGroup(
            children: [
              SettingsTile(
                key: const Key('backup-tile'),
                icon: Icons.save_alt,
                title: 'Backup & restore',
                subtitle: 'Encrypted .lybackup export and import',
                onTap: () => context.push('/settings/backup'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          VaultCard(
            padding: const EdgeInsets.all(AppSpacing.smd),
            child: AutoBackupSection(
              service: ref.watch(autoBackupServiceProvider),
              producer: ref.watch(ledgerBackupProducerProvider),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const SectionHeader(title: 'About'),
          VaultCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const SuiteAppIcon(app: SuiteApp.ledgerly, size: 44),
                    const SizedBox(width: AppSpacing.smd),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Ledgerly', style: AppTextStyles.h4),
                          Text(
                            'Version ${AppInfo.version}',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: c.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                const SuiteEndorsement(),
                const SizedBox(height: AppSpacing.md),
                Text(
                  AppInfo.privacyBlurb,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: c.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<String> _orderedCurrencies() => [
    ...Currencies.supported,
    if (!Currencies.supported.contains(_currency)) _currency,
  ];
}

/// "Check for updates on open" toggle + a manual "Check now", backed by
/// core_update. On by default; the only network call the app makes.
class _UpdateCheckTile extends ConsumerStatefulWidget {
  const _UpdateCheckTile();

  @override
  ConsumerState<_UpdateCheckTile> createState() => _UpdateCheckTileState();
}

class _UpdateCheckTileState extends ConsumerState<_UpdateCheckTile> {
  bool _checking = false;

  Future<void> _checkNow() async {
    setState(() => _checking = true);
    final info = await ref.read(updateServiceProvider).check();
    if (!mounted) return;
    setState(() => _checking = false);
    final messenger = ScaffoldMessenger.of(context);
    if (info == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text("You're on the latest version.")),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Update available · v${info.version}'),
          action: SnackBarAction(
            label: 'Update',
            onPressed: () => ref.read(updateServiceProvider).openDownload(info),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final autoCheck = ref.watch(updateAutoCheckProvider).valueOrNull ?? true;
    return RowGroup(
      children: [
        SettingsTile(
          icon: Icons.system_update_alt,
          title: 'Check on open',
          subtitle: 'Looks for a new release on GitHub',
          trailing: Switch(
            value: autoCheck,
            onChanged: (v) async {
              await ref
                  .read(secureStorageProvider)
                  .write(key: updateAutoCheckKey, value: v ? 'true' : 'false');
              ref.invalidate(updateAutoCheckProvider);
              ref.invalidate(updateCheckProvider);
            },
          ),
        ),
        SettingsTile(
          icon: Icons.refresh,
          title: 'Check now',
          trailing: _checking
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : null,
          onTap: _checking ? null : _checkNow,
        ),
      ],
    );
  }
}

import 'package:core_theme/core_theme.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ledgerly/src/features/settings/models/business_profile.dart';
import 'package:ledgerly/src/features/settings/services/logo_service.dart';

/// Business logo picker: shows the current logo (or a placeholder), lets
/// the user pick a new image from the gallery, and remove it. The image is
/// downscaled to 512px and stored inside the encrypted vault.
final class LogoSection extends StatefulWidget {
  const LogoSection({
    required this.profile,
    required this.onLogoChanged,
    super.key,
  });

  final BusinessProfile profile;
  final ValueChanged<String> onLogoChanged;

  @override
  State<LogoSection> createState() => _LogoSectionState();
}

final class _LogoSectionState extends State<LogoSection> {
  bool _busy = false;

  Future<void> _pick() async {
    setState(() => _busy = true);
    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (picked == null) return;
      final prepared = await LogoService.prepare(await picked.readAsBytes());
      if (!mounted) return;
      if (prepared == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("That image couldn't be read.")),
        );
        return;
      }
      widget.onLogoChanged(prepared);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final logoBytes = widget.profile.logoBytes;

    return VaultCard(
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(AppSpacing.borderRadius),
            ),
            clipBehavior: Clip.antiAlias,
            child: logoBytes == null
                ? Icon(
                    Icons.storefront_outlined,
                    color: theme.colorScheme.primary,
                  )
                : Image.memory(logoBytes, fit: BoxFit.contain),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Business logo', style: theme.textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  logoBytes == null
                      ? 'Appears at the top of your invoices.'
                      : 'Shown on your invoice PDFs.',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (_busy)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else ...[
            if (widget.profile.hasLogo)
              IconButton(
                tooltip: 'Remove logo',
                icon: const Icon(Icons.delete_outline, size: 20),
                onPressed: () => widget.onLogoChanged(''),
              ),
            TextButton(
              onPressed: _pick,
              child: Text(widget.profile.hasLogo ? 'Replace' : 'Add'),
            ),
          ],
        ],
      ),
    );
  }
}
